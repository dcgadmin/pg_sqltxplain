--
-- pg_sqltxplain initial setup, create necessary DB objects for storing and extrating metadata on database objects. enable extension pg_stat_statements as well;
--

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


ALTER TABLE IF EXISTS ONLY planstats.plan_table DROP CONSTRAINT IF EXISTS plan_table_pkey;
DROP VIEW IF EXISTS planstats.vw_table_stats;
DROP VIEW IF EXISTS planstats.vw_table_stats_wo_bloat;
DROP VIEW IF EXISTS planstats.vw_index_stats_tuple;
DROP VIEW IF EXISTS planstats.vw_index_stats;
DROP VIEW IF EXISTS planstats.vw_column_stats;
DROP TABLE IF EXISTS planstats.plan_table;
DROP FUNCTION IF EXISTS planstats.run_plan_explain(text, OUT planid integer, OUT queryid bigint);
DROP FUNCTION IF EXISTS planstats.run_plan_analyze(text, OUT planid integer, OUT queryid bigint);
DROP FUNCTION IF EXISTS planstats.extract_info(jsonb, text);
DROP FUNCTION IF EXISTS planstats.extract_filters(jsonb);
DROP FUNCTION IF EXISTS planstats.extract_all_nodes(jsonb);
DROP FUNCTION IF EXISTS planstats.generate_recommendations(integer);
DROP SCHEMA IF EXISTS planstats;
--
-- Name: planstats; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA planstats;

CREATE FUNCTION planstats.extract_filters(jsonb) RETURNS TABLE(objname text)
    LANGUAGE sql
    AS $_$
WITH filterlist as 
(select 'Filter,Sort Key,Group Key,Hash Key,Presorted Key,Cache Key,Join Filter,One-Time Filter,Conflict Filter,Hash Cond,Run Condition,Index Cond,Recheck Cond,TID Cond,Merge Cond,Order By,Recheck Cond,Heap Fetches,Pre-sorted,Full-sort,Function Call,Table Function Call,Function Name,Table Function Name' as filters)
select objname
from (select unnest(regexp_split_to_array((select filters from filterlist),',')) as f ) as filters, lateral extract_info(($1),filters.f);
$_$;


CREATE FUNCTION planstats.extract_all_nodes(p_json jsonb)
RETURNS TABLE(node_id integer, depth integer, node jsonb)
LANGUAGE sql AS $_$
WITH RECURSIVE nodes(id, d, n) AS (
    SELECT 1, 0, p_json->0->'Plan'
  UNION ALL
    SELECT id + rn::int + 1, d + 1, n->'Plans'->rn
    FROM nodes,
         LATERAL generate_series(0, jsonb_array_length(COALESCE(n->'Plans','[]'::jsonb)) - 1) AS rn
    WHERE jsonb_array_length(COALESCE(n->'Plans','[]'::jsonb)) >= 1
)
SELECT id, d, n FROM nodes;
$_$;


CREATE FUNCTION planstats.generate_recommendations(p_planid integer)
RETURNS TABLE(
    severity text,
    category text,
    finding text,
    recommendation text,
    details text
)
LANGUAGE plpgsql AS $_X$
DECLARE
    v_json jsonb;
    v_queryid bigint;
BEGIN
    -- Get the plan JSON and queryid
    SELECT jsonplan::jsonb, pt.queryid
    INTO v_json, v_queryid
    FROM planstats.plan_table pt
    WHERE pt.planid = p_planid;

    IF v_json IS NULL THEN
        RETURN;
    END IF;

    CREATE TEMP TABLE IF NOT EXISTS tmp_recommendations (
        severity text,
        category text,
        finding text,
        recommendation text,
        details text
    ) ON COMMIT DROP;

    DELETE FROM tmp_recommendations;

    -- Rule A: Rows Removed by Filter >> Actual Rows (HIGH / INDEX)
    INSERT INTO tmp_recommendations
    SELECT 'HIGH', 'INDEX',
        'Seq Scan on ' || COALESCE(n.node->>'Relation Name', 'unknown') ||
        ' removed ' || (n.node->>'Rows Removed by Filter') ||
        ' rows by filter but returned only ' || (n.node->>'Actual Rows') || ' rows',
        'Create an index on the filter columns. Consider a covering index with INCLUDE clause to enable Index Only Scan.',
        'Filter: ' || COALESCE(n.node->>'Filter', 'N/A')
    FROM planstats.extract_all_nodes(v_json) n
    WHERE n.node ? 'Rows Removed by Filter'
      AND (n.node->>'Rows Removed by Filter')::numeric >
          10 * GREATEST((n.node->>'Actual Rows')::numeric, 1);

    -- Rule B: Sequential Scan on Large Table with Filter (HIGH / INDEX)
    INSERT INTO tmp_recommendations
    SELECT 'HIGH', 'INDEX',
        'Sequential scan on ' || COALESCE(n.node->>'Relation Name', 'unknown') ||
        ' reading ' || COALESCE(n.node->>'Actual Rows', n.node->>'Plan Rows') ||
        ' rows with filter: ' || COALESCE(n.node->>'Filter', 'N/A'),
        'Consider creating an index on columns used in the filter condition to avoid full table scan.',
        'Table: ' || COALESCE(n.node->>'Schema', '') || '.' || COALESCE(n.node->>'Relation Name', 'unknown')
    FROM planstats.extract_all_nodes(v_json) n
    WHERE n.node->>'Node Type' = 'Seq Scan'
      AND n.node ? 'Filter'
      AND COALESCE((n.node->>'Actual Rows')::numeric, (n.node->>'Plan Rows')::numeric, 0) > 10000
      -- Avoid duplicate with Rule A when both fire
      AND NOT (
          n.node ? 'Rows Removed by Filter'
          AND (n.node->>'Rows Removed by Filter')::numeric >
              10 * GREATEST(COALESCE((n.node->>'Actual Rows')::numeric, 1), 1)
      );

    -- Rule C: Sort Spilling to Disk (HIGH / CONFIGURATION)
    INSERT INTO tmp_recommendations
    SELECT 'HIGH', 'CONFIGURATION',
        'Sort operation spilled to disk using ' || (n.node->>'Sort Space Used') || 'kB',
        'Increase work_mem to allow in-memory sorting. Current sort requires ' ||
        (n.node->>'Sort Space Used') || 'kB.',
        'Sort Key: ' || COALESCE(n.node->>'Sort Key', 'N/A')
    FROM planstats.extract_all_nodes(v_json) n
    WHERE n.node->>'Node Type' = 'Sort'
      AND n.node->>'Sort Space Type' = 'Disk';

    -- Rule D: Hash Batches Exceeding Plan (MEDIUM / CONFIGURATION)
    INSERT INTO tmp_recommendations
    SELECT 'MEDIUM', 'CONFIGURATION',
        'Hash operation used ' || (n.node->>'Hash Batches') ||
        ' batches (originally planned ' || COALESCE(n.node->>'Original Hash Batches', '1') || ')',
        'Increase work_mem to reduce hash batches. Multiple batches cause disk I/O.',
        'Hash Buckets: ' || COALESCE(n.node->>'Hash Buckets', 'N/A')
    FROM planstats.extract_all_nodes(v_json) n
    WHERE n.node ? 'Hash Batches'
      AND (n.node->>'Hash Batches')::int > 1;

    -- Rule E: Plan Row Estimate Errors (MEDIUM / STATISTICS)
    INSERT INTO tmp_recommendations
    SELECT 'MEDIUM', 'STATISTICS',
        'Planner estimated ' || (n.node->>'Plan Rows') ||
        ' rows but actual was ' || (n.node->>'Actual Rows') ||
        ' rows for ' || COALESCE(n.node->>'Node Type', 'unknown') ||
        ' on ' || COALESCE(n.node->>'Relation Name', n.node->>'Index Name', 'unknown'),
        'Run ANALYZE on the table. If persistent, increase default_statistics_target or create extended statistics for correlated columns.',
        'Estimation ratio: ' ||
        CASE WHEN (n.node->>'Actual Rows')::numeric > (n.node->>'Plan Rows')::numeric
             THEN round((n.node->>'Actual Rows')::numeric / GREATEST((n.node->>'Plan Rows')::numeric, 1), 1) || 'x underestimate'
             ELSE round((n.node->>'Plan Rows')::numeric / GREATEST((n.node->>'Actual Rows')::numeric, 1), 1) || 'x overestimate'
        END
    FROM planstats.extract_all_nodes(v_json) n
    WHERE n.node ? 'Actual Rows' AND n.node ? 'Plan Rows'
      AND (n.node->>'Plan Rows')::numeric > 0
      AND (
          (n.node->>'Actual Rows')::numeric / GREATEST((n.node->>'Plan Rows')::numeric, 1) > 10
          OR
          (n.node->>'Plan Rows')::numeric / GREATEST((n.node->>'Actual Rows')::numeric, 1) > 10
      );

    -- Rule F: Index Only Scan with High Heap Fetches (MEDIUM / VACUUM)
    INSERT INTO tmp_recommendations
    SELECT 'MEDIUM', 'VACUUM',
        'Index Only Scan on ' || COALESCE(n.node->>'Index Name', 'unknown') ||
        ' required ' || (n.node->>'Heap Fetches') ||
        ' heap fetches for ' || (n.node->>'Actual Rows') || ' rows',
        'Run VACUUM on table ' || COALESCE(n.node->>'Schema', '') || '.' ||
        COALESCE(n.node->>'Relation Name', 'unknown') ||
        ' to update the visibility map and reduce heap fetches.',
        NULL
    FROM planstats.extract_all_nodes(v_json) n
    WHERE n.node->>'Node Type' = 'Index Only Scan'
      AND n.node ? 'Heap Fetches'
      AND (n.node->>'Heap Fetches')::numeric >
          0.5 * GREATEST((n.node->>'Actual Rows')::numeric, 1);

    -- Rule G: Lossy Bitmap Heap Scan (MEDIUM / CONFIGURATION)
    INSERT INTO tmp_recommendations
    SELECT 'MEDIUM', 'CONFIGURATION',
        'Bitmap Heap Scan had ' || (n.node->>'Lossy Heap Blocks') ||
        ' lossy blocks vs ' || COALESCE(n.node->>'Exact Heap Blocks', '0') || ' exact blocks',
        'Increase work_mem to allow exact bitmap rather than lossy. Lossy bitmaps recheck all rows in affected pages.',
        'Table: ' || COALESCE(n.node->>'Relation Name', 'unknown')
    FROM planstats.extract_all_nodes(v_json) n
    WHERE n.node->>'Node Type' = 'Bitmap Heap Scan'
      AND n.node ? 'Lossy Heap Blocks'
      AND (n.node->>'Lossy Heap Blocks')::numeric > 0;

    -- Rule H: Nested Loop with Large Inner (LOW / QUERY)
    INSERT INTO tmp_recommendations
    SELECT 'LOW', 'QUERY',
        'Nested Loop on ' || COALESCE(n.node->>'Node Type', '') ||
        ' processes large number of rows (' || (n.node->>'Actual Rows') ||
        ' rows x ' || COALESCE(n.node->>'Actual Loops', '1') || ' loops)',
        'Consider restructuring the query or adding indexes to reduce inner loop iterations. Hash Join may be more efficient for large datasets.',
        NULL
    FROM planstats.extract_all_nodes(v_json) n
    WHERE n.node->>'Node Type' = 'Nested Loop'
      AND n.node ? 'Actual Rows'
      AND (n.node->>'Actual Rows')::numeric *
          COALESCE((n.node->>'Actual Loops')::numeric, 1) > 100000;

    -- Rule I: Parallel Query Not Used on Large Scan (LOW / CONFIGURATION)
    INSERT INTO tmp_recommendations
    SELECT 'LOW', 'CONFIGURATION',
        'Large sequential scan (' ||
        COALESCE(n.node->>'Actual Rows', n.node->>'Plan Rows') ||
        ' rows) without parallel workers on ' ||
        COALESCE(n.node->>'Relation Name', 'unknown'),
        'Check max_parallel_workers_per_gather and min_parallel_table_scan_size settings. Parallel scan could significantly reduce execution time.',
        NULL
    FROM planstats.extract_all_nodes(v_json) n
    WHERE n.node->>'Node Type' = 'Seq Scan'
      AND COALESCE((n.node->>'Actual Rows')::numeric, (n.node->>'Plan Rows')::numeric, 0) > 100000
      AND NOT n.node ? 'Workers Planned';

    -- Rule J: Table Bloat > 20% (MEDIUM / VACUUM)
    INSERT INTO tmp_recommendations
    SELECT 'MEDIUM', 'VACUUM',
        'Table ' || tbls."Sname" || '.' || tbls.relname ||
        ' has ' || tbls."BloatPCT%" || '% bloat (' || tbls."BloatSize%" || ')',
        'Run VACUUM FULL or use pg_repack to reclaim space. High bloat increases I/O and scan times.',
        'Table size: ' || tbls."Size"
    FROM planstats.extract_info(v_json, 'Relation Name') ei
    JOIN planstats.vw_table_stats tbls
      ON tbls.oid = (ei.schname || '.' || ei.objname)::regclass::oid
    WHERE tbls."BloatPCT%" > 20;

    -- Rule K: Missing Statistics (HIGH / STATISTICS)
    INSERT INTO tmp_recommendations
    SELECT 'HIGH', 'STATISTICS',
        'Table ' || tbls."Sname" || '.' || tbls.relname || ' has no column statistics',
        'Run: ANALYZE ' || tbls."Sname" || '.' || tbls.relname ||
        '; Missing statistics cause the planner to make poor estimates.',
        NULL
    FROM planstats.extract_info(v_json, 'Relation Name') ei
    JOIN planstats.vw_table_stats tbls
      ON tbls.oid = (ei.schname || '.' || ei.objname)::regclass::oid
    WHERE tbls."MissingStats" = true;

    -- Rule L: Dead Tuples / Autovacuum Overdue (MEDIUM / VACUUM)
    INSERT INTO tmp_recommendations
    SELECT 'MEDIUM', 'VACUUM',
        'Table ' || tbls."Sname" || '.' || tbls.relname ||
        ' has ' || tbls."Dtup" || ' dead tuples and autovacuum is overdue',
        'Run: VACUUM ' || tbls."Sname" || '.' || tbls.relname ||
        '; Dead tuples waste space and slow scans.',
        'Autovacuum threshold: ' || tbls.av_threshold
    FROM planstats.extract_info(v_json, 'Relation Name') ei
    JOIN planstats.vw_table_stats tbls
      ON tbls.oid = (ei.schname || '.' || ei.objname)::regclass::oid
    WHERE tbls.expect_av = 'Due To Run';

    -- Rule M: Low Column Correlation with Index Scan (LOW / INDEX)
    INSERT INTO tmp_recommendations
    SELECT DISTINCT 'LOW', 'INDEX',
        'Column ' || cols."CName" || ' on ' || cols."TName" ||
        ' has low correlation (' || cols."Cluster" || '), used in Index Scan',
        'Low correlation means random I/O during index scans. Consider CLUSTER on this index, or a BRIN index if data has natural ordering.',
        NULL
    FROM planstats.extract_all_nodes(v_json) n
    JOIN planstats.extract_info(v_json, 'Relation Name') ei ON true
    JOIN planstats.vw_column_stats cols
      ON cols.oid = (ei.schname || '.' || ei.objname)::regclass::oid
    WHERE n.node->>'Node Type' IN ('Index Scan', 'Index Only Scan')
      AND n.node->>'Relation Name' = ei.objname
      AND ABS(cols."Cluster") < 0.1
      AND cols."Cluster" IS NOT NULL
      AND (COALESCE(n.node->>'Index Cond', '') || COALESCE(n.node->>'Filter', '')) ~* cols."CName";

    -- Rule N: Temp File Usage from pg_stat_statements (MEDIUM / CONFIGURATION)
    IF v_queryid IS NOT NULL AND EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_stat_statements') THEN
        EXECUTE format(
            'INSERT INTO tmp_recommendations
             SELECT ''MEDIUM'', ''CONFIGURATION'',
                 ''Query wrote '' || temp_blks_written || '' temp blocks to disk'',
                 ''Increase work_mem to reduce temp file usage. Temp files cause significant I/O overhead.'',
                 ''Temp blocks read: '' || temp_blks_read
             FROM pg_stat_statements
             WHERE queryid = %s AND temp_blks_written > 0',
            v_queryid
        );
    END IF;

    RETURN QUERY SELECT t.severity, t.category, t.finding, t.recommendation, t.details
    FROM tmp_recommendations t;
END;
$_X$;


CREATE FUNCTION planstats.extract_info(jsonb, text) RETURNS TABLE(objname text, schname text)
    LANGUAGE sql
    AS $_$
with recursive alias1 as (select $1->0->'Plan' as plan1) , 
alias2(plans) as (
select  plan1->'Plans'  --$1::jsonb->'Plans' 
    from alias1
union all 
select  plans ->i->'Plans'
from  alias2 , lateral generate_series(0,jsonb_array_length((plans))) as i
where jsonb_array_length((plans))>=1)
select  plans->i->> $2 , 
    case 
    when $2 IN ('Relation Name','Trigger Name','Constraint Name','Index Name','Function Name','Table Function Name','Tuplestore Name')
    then plans->i ->> 'Schema' end
from alias2 , lateral generate_series(0,jsonb_array_length((plans))) as i 
where plans->i ? $2
union 
select plan1->> $2 , 
case 
    when $2 IN ('Relation Name','Trigger Name','Constraint Name','Index Name','Function Name','Table Function Name','Tuplestore Name')
    then plan1 ->> 'Schema' end
from alias1
where plan1 ? $2
$_$;


CREATE OR REPLACE FUNCTION planstats.run_plan_analyze(text, OUT planid integer, OUT queryid bigint) RETURNS record
    LANGUAGE plpgsql SECURITY DEFINER
    SET "pg_stat_statements.track" TO 'all'
    SET "pg_stat_statements.track_planning" TO 'on'
    SET compute_query_id = 'on'
    AS $_X$
declare 
var1 text := '';
var2 text;
i text;
begin

FOR i in EXECUTE FORMAT($_$EXPLAIN (ANALYZE, COSTS, VERBOSE, TIMING, BUFFERS) 
%s$_$,$1) 
loop 
var1 := concat_ws('',var1 ,chr(10), i);
end loop;

EXECUTE FORMAT($_$EXPLAIN (COSTS,VERBOSE,FORMAT JSON,SETTINGS) 
%s$_$,$1) into var2;

queryid := CASE WHEN var2::jsonb->0 ? 'Query Identifier' THEN var2::jsonb->0 ->> 'Query Identifier' END ;

EXECUTE FORMAT('insert into planstats.plan_table(queryid,sql, jsonplan,plainplan) 
values (%s,$_$%s$_$,$_$%s$_$,$_$%s$_$) returning planid',queryid,$1,var2,var1) into planid ; 
end;
$_X$;


CREATE OR REPLACE FUNCTION planstats.run_plan_explain(text, OUT planid integer, OUT queryid bigint) RETURNS record
    LANGUAGE plpgsql SECURITY DEFINER
    SET "pg_stat_statements.track_planning" TO 'on'
    SET client_min_messages TO 'warning'
    SET compute_query_id = 'on'
    AS $_$
declare 
var1 text := '';
var2 text;
i text;

begin

IF split_part(current_setting('server_version'),' ',1)::real::int >= 16 THEN

FOR i in EXECUTE FORMAT($DYNAMIC$EXPLAIN (COSTS, VERBOSE, SETTINGS, GENERIC_PLAN) 
%s$DYNAMIC$,$1) 
loop 
var1 := concat_ws('',var1 ,chr(10), i);
end loop;

EXECUTE FORMAT($DYNAMIC$EXPLAIN (COSTS,VERBOSE,FORMAT JSON,SETTINGS,GENERIC_PLAN) 
%s$DYNAMIC$,$1) into var2;

ELSE
FOR i in EXECUTE FORMAT($DYNAMIC$EXPLAIN (COSTS, VERBOSE, TIMING, SETTINGS) 
%s$DYNAMIC$,$1) 
loop 
var1 := concat_ws('',var1 ,chr(10), i);
end loop;

EXECUTE FORMAT($DYNAMIC$EXPLAIN (COSTS,VERBOSE,FORMAT JSON,SETTINGS) 
%s$DYNAMIC$,$1) into var2;

END IF;

queryid := CASE WHEN var2::jsonb->0 ? 'Query Identifier' THEN var2::jsonb->0 ->> 'Query Identifier' END ;

EXECUTE FORMAT('insert into planstats.plan_table(queryid,sql, jsonplan,plainplan) 
values (%s,$S$%s$S$,$S$%s$S$,$S$%s$S$) returning planid',queryid,$1,var2,var1) into planid ; 
end;
$_$;


CREATE TABLE planstats.plan_table (
    planid bigint NOT NULL,
    queryid bigint,
    sql text,
    jsonplan text,
    plainplan text,
    date_generated timestamp without time zone DEFAULT (now())::timestamp without time zone
);


ALTER TABLE planstats.plan_table ALTER COLUMN planid ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME planstats.plan_table_planid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

CREATE VIEW planstats.vw_column_stats AS
SELECT a.attrelid as oid, ( SELECT ((pg_class.relnamespace)::regnamespace)::text AS relnamespace
           FROM pg_class
          WHERE (pg_class.oid = a.attrelid)) AS "SName",
    ((a.attrelid)::regclass)::text AS "TName",
    a.attname AS "CName",
    format_type(a.atttypid, a.atttypmod) AS "Type",
        CASE
            WHEN a.attnotnull THEN 'NOT NULL'::text
            ELSE 'NULL'::text
        END AS "NULL?",
    round((pg_stats.null_frac)::numeric, 2) AS "Null%",
    pg_stats.n_distinct AS "Distnct",
    round((pg_stats.correlation)::numeric, 3) AS "Cluster",
       ROUND(CASE
        WHEN pg_stats.n_distinct > 0 THEN (nullif((SELECT reltuples FROM pg_class WHERE pg_class.oid = a.attrelid),0)*(1-pg_stats.null_frac))/n_distinct
        ELSE (nullif((SELECT reltuples FROM pg_class WHERE pg_class.oid = a.attrelid),0)*(1-pg_stats.null_frac))/nullif((abs(n_distinct)*(nullif((SELECT reltuples FROM pg_class WHERE pg_class.oid = a.attrelid),0)*(1-pg_stats.null_frac))),0)
    END::numeric,2) AS "Selectivity",
    (((pg_stats.most_common_vals)::text)::text[])[1:5] AS "MCV",
    (((pg_stats.most_common_freqs)::text)::text[])[1:5] AS "MVF",
        CASE a.attstorage
            WHEN 'p'::"char" THEN 'plain'::text
            WHEN 'e'::"char" THEN 'external'::text
            WHEN 'm'::"char" THEN 'main'::text
            WHEN 'x'::"char" THEN 'extended'::text
            ELSE NULL::text
        END AS "Store",
        CASE
            WHEN (a.attstorage <> 'p'::"char") THEN
            CASE a.attcompression
                WHEN 'p'::"char" THEN 'pglz'::text
                WHEN 'l'::"char" THEN 'LZ4'::text
                ELSE NULL::text
            END
            ELSE NULL::text
        END AS "Cmprssn",
        CASE
            WHEN (a.attstattarget = '-1'::integer) THEN NULL::smallint
            ELSE a.attstattarget
        END AS "StatTarget"
   FROM (pg_attribute a
     LEFT JOIN pg_stats ON (((a.attrelid = (((((pg_stats.schemaname)::text || '.'::text) || (pg_stats.tablename)::text))::regclass)::oid) AND (a.attname = pg_stats.attname))))
  WHERE ((a.attnum > 0) AND (NOT a.attisdropped));

CREATE VIEW planstats.vw_index_stats AS
 SELECT schemaname AS "Sname",
    relname,
    indexrelname,
    pg_size_pretty(pg_table_size(((((((schemaname)::text || '.'::text) || (indexrelname)::text))::regclass)::oid)::regclass)) AS "Size",
    to_char(last_idx_scan, 'DD-MON-YY HH24:MI:SS'::text) AS "LScan",
    idx_scan AS "Scan",
    idx_tup_read AS "TRead",
    idx_tup_fetch AS "TFetch",
    ( SELECT TRIM(BOTH FROM regexp_replace(idx.indexdef, (((((('(CREATE|INDEX|ON|USING|'::text || (idx.indexname)::text) || '|'::text) || (idx.schemaname)::text) || '.'::text) || (idx.tablename)::text) || ')'::text), ''::text, 'gi'::text)) AS btrim
           FROM pg_indexes idx
          WHERE ((idx.schemaname = pg_stat_user_indexes.schemaname) AND (idx.tablename = pg_stat_user_indexes.relname) AND (idx.indexname = pg_stat_user_indexes.indexrelname))) AS "Details"
   FROM pg_stat_user_indexes;


CREATE VIEW planstats.vw_table_stats_wo_bloat AS
 SELECT pg_class.oid,
    pg_tables.schemaname AS "Sname",
    pg_tables.tablename AS relname,
    pg_size_pretty(pg_table_size((pg_class.oid)::regclass)) AS "Size",
    pg_class.reltuples AS "Ltup",
    pg_class.relpages AS "Pages",
    pg_stat_user_tables.n_dead_tup AS "Dtup",
    COALESCE(( SELECT 'Y'::text AS text
           FROM pg_partitioned_table
          WHERE (pg_partitioned_table.partrelid = pg_class.oid)), 'N'::text) AS "Part",
    (((COALESCE(pg_stat_user_tables.n_tup_ins, (0)::bigint) + (2 * COALESCE(pg_stat_user_tables.n_tup_upd, (0)::bigint))) - COALESCE(pg_stat_user_tables.n_tup_hot_upd, (0)::bigint)) + COALESCE(pg_stat_user_tables.n_tup_del, (0)::bigint)) AS total_writes,
    ((((COALESCE(pg_stat_user_tables.n_tup_hot_upd, (0)::bigint))::double precision * (100)::double precision) / (
        CASE
            WHEN (pg_stat_user_tables.n_tup_upd > 0) THEN pg_stat_user_tables.n_tup_upd
            ELSE (1)::bigint
        END)::double precision))::numeric(10,2) AS hot_rate,
    ( SELECT r.v[1] AS v
           FROM regexp_matches((pg_class.reloptions)::text, 'fillfactor=(d+)'::text) r(v)
         LIMIT 1) AS fillfactor,
    COALESCE(( SELECT r.v[1] AS v
           FROM regexp_matches((pg_class.reloptions)::text, 'autovacuum_vacuum_threshold=(d+)'::text) r(v)
         LIMIT 1), current_setting('autovacuum_vacuum_threshold'::text)) AS autovacuum_vacuum_threshold,
    COALESCE(( SELECT r.v[1] AS v
           FROM regexp_matches((pg_class.reloptions)::text, 'autovacuum_vacuum_scale_factor=(d+)'::text) r(v)
         LIMIT 1), current_setting('autovacuum_vacuum_scale_factor'::text)) AS autovacuum_vacuum_scale_factor,
    to_char(GREATEST(pg_stat_user_tables.last_vacuum, pg_stat_user_tables.last_autovacuum), 'DD-MON-YY HH24:MI:SS'::text) AS "LVacuum",
    to_char(GREATEST(pg_stat_user_tables.last_analyze, pg_stat_user_tables.last_autoanalyze), 'DD-MON-YY HH24:MI:SS'::text) AS "LAnalyze",
    to_char((((COALESCE(( SELECT r.v[1] AS v
           FROM regexp_matches((pg_class.reloptions)::text, 'autovacuum_vacuum_threshold=(d+)'::text) r(v)
         LIMIT 1), current_setting('autovacuum_vacuum_threshold'::text)))::bigint)::double precision + (((COALESCE(( SELECT r.v[1] AS v
           FROM regexp_matches((pg_class.reloptions)::text, 'autovacuum_vacuum_scale_factor=(d+)'::text) r(v)
         LIMIT 1), current_setting('autovacuum_vacuum_scale_factor'::text)))::numeric)::double precision * pg_class.reltuples)), '9G999G999G999'::text) AS av_threshold,
        CASE
            WHEN ((((COALESCE(( SELECT r.v[1] AS v
               FROM regexp_matches((pg_class.reloptions)::text, 'autovacuum_vacuum_threshold=(d+)'::text) r(v)
             LIMIT 1), current_setting('autovacuum_vacuum_threshold'::text)))::bigint)::double precision + (((COALESCE(( SELECT r.v[1] AS v
               FROM regexp_matches((pg_class.reloptions)::text, 'autovacuum_vacuum_scale_factor=(d+)'::text) r(v)
             LIMIT 1), current_setting('autovacuum_vacuum_scale_factor'::text)))::numeric)::double precision * pg_class.reltuples)) < (pg_stat_user_tables.n_dead_tup)::double precision) THEN 'Due To Run'::text
            ELSE ''::text
        END AS expect_av,
    COALESCE(( SELECT 'Y'::text AS text
           FROM pg_publication_tables p
          WHERE ((p.schemaname = pg_stat_user_tables.schemaname) AND (p.tablename = pg_class.relname))
         LIMIT 1), 'N'::text) AS "Pubs",
      (pg_stat_get_live_tuples(pg_class.oid) != 0 AND  NOT EXISTS (SELECT 1 FROM pg_statistic WHERE starelid=pg_class.oid))   "MissingStats"
   FROM ((pg_class
     JOIN pg_tables ON ((pg_class.oid = (((((pg_tables.schemaname)::text || '.'::text) || (pg_tables.tablename)::text))::regclass)::oid)))
     LEFT JOIN pg_stat_user_tables ON (((pg_tables.schemaname = pg_stat_user_tables.schemaname) AND (pg_tables.tablename = pg_stat_user_tables.relname))));


CREATE VIEW planstats.vw_table_stats AS
 WITH constants AS (
         SELECT (current_setting('block_size'::text))::numeric AS bs,
            23 AS hdr,
            8 AS ma
        ), no_stats AS (
         SELECT columns.table_schema,
            columns.table_name,
            (psut.n_live_tup)::numeric AS est_rows,
            (pg_table_size((psut.relid)::regclass))::numeric AS table_size
           FROM ((information_schema.columns
             JOIN pg_stat_user_tables psut ON ((((columns.table_schema)::name = psut.schemaname) AND ((columns.table_name)::name = psut.relname))))
             LEFT JOIN pg_stats ON ((((columns.table_schema)::name = pg_stats.schemaname) AND ((columns.table_name)::name = pg_stats.tablename) AND ((columns.column_name)::name = pg_stats.attname))))
          WHERE ((pg_stats.attname IS NULL) AND ((columns.table_schema)::name <> ALL (ARRAY['pg_catalog'::name, 'information_schema'::name])))
          GROUP BY columns.table_schema, columns.table_name, psut.relid, psut.n_live_tup
        ), null_headers AS (
         SELECT ((constants.hdr + 1) + (sum(
                CASE
                    WHEN (pg_stats.null_frac <> (0)::double precision) THEN 1
                    ELSE 0
                END) / 8)) AS nullhdr,
            sum((((1)::double precision - pg_stats.null_frac) * (pg_stats.avg_width)::double precision)) AS datawidth,
            max(pg_stats.null_frac) AS maxfracsum,
            pg_stats.schemaname,
            pg_stats.tablename,
            constants.hdr,
            constants.ma,
            constants.bs
           FROM ((pg_stats
             CROSS JOIN constants)
             LEFT JOIN no_stats ON (((pg_stats.schemaname = (no_stats.table_schema)::name) AND (pg_stats.tablename = (no_stats.table_name)::name))))
          WHERE ((pg_stats.schemaname <> ALL (ARRAY['pg_catalog'::name, 'information_schema'::name])) AND (no_stats.table_name IS NULL) AND (EXISTS ( SELECT 1
                   FROM information_schema.columns
                  WHERE ((pg_stats.schemaname = (columns.table_schema)::name) AND (pg_stats.tablename = (columns.table_name)::name)))))
          GROUP BY pg_stats.schemaname, pg_stats.tablename, constants.hdr, constants.ma, constants.bs
        ), data_headers AS (
         SELECT null_headers.ma,
            null_headers.bs,
            null_headers.hdr,
            null_headers.schemaname,
            null_headers.tablename,
            ((null_headers.datawidth + (((null_headers.hdr + null_headers.ma) -
                CASE
                    WHEN ((null_headers.hdr % null_headers.ma) = 0) THEN null_headers.ma
                    ELSE (null_headers.hdr % null_headers.ma)
                END))::double precision))::numeric AS datahdr,
            (null_headers.maxfracsum * (((null_headers.nullhdr + null_headers.ma) -
                CASE
                    WHEN ((null_headers.nullhdr % (null_headers.ma)::bigint) = 0) THEN (null_headers.ma)::bigint
                    ELSE (null_headers.nullhdr % (null_headers.ma)::bigint)
                END))::double precision) AS nullhdr2
           FROM null_headers
        ), table_estimates AS (
         SELECT data_headers.schemaname,
            data_headers.tablename,
            data_headers.bs,
            (pg_class_1.reltuples)::numeric AS est_rows,
            ((pg_class_1.relpages)::numeric * data_headers.bs) AS table_bytes,
            (ceil(((pg_class_1.reltuples * (((((data_headers.datahdr)::double precision + data_headers.nullhdr2) + (4)::double precision) + (data_headers.ma)::double precision) - (
                CASE
                    WHEN ((data_headers.datahdr % (data_headers.ma)::numeric) = (0)::numeric) THEN (data_headers.ma)::numeric
                    ELSE (data_headers.datahdr % (data_headers.ma)::numeric)
                END)::double precision)) / ((data_headers.bs - (20)::numeric))::double precision)) * (data_headers.bs)::double precision) AS expected_bytes,
            pg_class_1.reltoastrelid
           FROM ((data_headers
             JOIN pg_class pg_class_1 ON ((data_headers.tablename = pg_class_1.relname)))
             JOIN pg_namespace ON (((pg_class_1.relnamespace = pg_namespace.oid) AND (data_headers.schemaname = pg_namespace.nspname))))
          WHERE (pg_class_1.relkind = 'r'::"char")
        ), estimates_with_toast AS (
         SELECT table_estimates.schemaname,
            table_estimates.tablename,
            true AS can_estimate,
            table_estimates.est_rows,
            (table_estimates.table_bytes + ((COALESCE(toast.relpages, 0))::numeric * table_estimates.bs)) AS table_bytes,
            (table_estimates.expected_bytes + (ceil((COALESCE(toast.reltuples, (0)::real) / (4)::double precision)) * (table_estimates.bs)::double precision)) AS expected_bytes
           FROM (table_estimates
             LEFT JOIN pg_class toast ON (((table_estimates.reltoastrelid = toast.oid) AND (toast.relkind = 't'::"char"))))
        ), table_estimates_plus AS (
         SELECT current_database() AS databasename,
            estimates_with_toast.schemaname,
            estimates_with_toast.tablename,
            estimates_with_toast.can_estimate,
            estimates_with_toast.est_rows,
                CASE
                    WHEN (estimates_with_toast.table_bytes > (0)::numeric) THEN estimates_with_toast.table_bytes
                    ELSE NULL::numeric
                END AS table_bytes,
                CASE
                    WHEN (estimates_with_toast.expected_bytes > (0)::double precision) THEN (estimates_with_toast.expected_bytes)::numeric
                    ELSE NULL::numeric
                END AS expected_bytes,
                CASE
                    WHEN ((estimates_with_toast.expected_bytes > (0)::double precision) AND (estimates_with_toast.table_bytes > (0)::numeric) AND (estimates_with_toast.expected_bytes <= (estimates_with_toast.table_bytes)::double precision)) THEN (((estimates_with_toast.table_bytes)::double precision - estimates_with_toast.expected_bytes))::numeric
                    ELSE (0)::numeric
                END AS bloat_bytes
           FROM estimates_with_toast
        UNION ALL
         SELECT current_database() AS databasename,
            no_stats.table_schema,
            no_stats.table_name,
            false,
            no_stats.est_rows,
            no_stats.table_size,
            NULL::numeric AS "numeric",
            NULL::numeric AS "numeric"
           FROM no_stats
        ), bloat_data AS (
         SELECT current_database() AS databasename,
            table_estimates_plus.schemaname,
            table_estimates_plus.tablename,
            table_estimates_plus.can_estimate,
            table_estimates_plus.table_bytes,
            round((table_estimates_plus.table_bytes / (((1024)::double precision ^ (2)::double precision))::numeric), 3) AS table_mb,
            table_estimates_plus.expected_bytes,
            round((table_estimates_plus.expected_bytes / (((1024)::double precision ^ (2)::double precision))::numeric), 3) AS expected_mb,
            round(((table_estimates_plus.bloat_bytes * (100)::numeric) / table_estimates_plus.table_bytes)) AS pct_bloat,
            table_estimates_plus.bloat_bytes AS bloatbytes,
            table_estimates_plus.table_bytes,
            table_estimates_plus.expected_bytes,
            table_estimates_plus.est_rows
           FROM table_estimates_plus
        )
 SELECT pg_class.oid , pg_tables.schemaname AS "Sname",
    pg_tables.tablename AS relname,
    pg_size_pretty(pg_table_size(((((((pg_tables.schemaname)::text || '.'::text) || (pg_tables.tablename)::text))::regclass)::oid)::regclass)) AS "Size",
    pg_class.reltuples AS "Ltup",
    pg_class.relpages AS "Pages",
    pg_stat_user_tables.n_dead_tup AS "Dtup",
    COALESCE(( SELECT 'Y'::text
           FROM pg_partitioned_table
          WHERE (pg_partitioned_table.partrelid = (((((pg_stat_user_tables.schemaname)::text || '.'::text) || (pg_class.relname)::text))::regclass)::oid)), 'N'::text) AS "Part",
    floor(bloat_data.pct_bloat) AS "BloatPCT%",
    pg_size_pretty(bloat_data.bloatbytes) AS "BloatSize%",
    (((COALESCE(pg_stat_user_tables.n_tup_ins, (0)::bigint) + (2 * COALESCE(pg_stat_user_tables.n_tup_upd, (0)::bigint))) - COALESCE(pg_stat_user_tables.n_tup_hot_upd, (0)::bigint)) + COALESCE(pg_stat_user_tables.n_tup_del, (0)::bigint)) AS total_writes,
    ((((COALESCE(pg_stat_user_tables.n_tup_hot_upd, (0)::bigint))::double precision * (100)::double precision) / (
        CASE
            WHEN (pg_stat_user_tables.n_tup_upd > 0) THEN pg_stat_user_tables.n_tup_upd
            ELSE (1)::bigint
        END)::double precision))::numeric(10,2) AS hot_rate,
    ( SELECT r.v[1] AS v
           FROM regexp_matches((pg_class.reloptions)::text, 'fillfactor=(d+)'::text) r(v)
         LIMIT 1) AS fillfactor,
    COALESCE(( SELECT r.v[1] AS v
           FROM regexp_matches((pg_class.reloptions)::text, 'autovacuum_vacuum_threshold=(d+)'::text) r(v)
         LIMIT 1), current_setting('autovacuum_vacuum_threshold'::text)) AS autovacuum_vacuum_threshold,
    COALESCE(( SELECT r.v[1] AS v
           FROM regexp_matches((pg_class.reloptions)::text, 'autovacuum_vacuum_scale_factor=(d+)'::text) r(v)
         LIMIT 1), current_setting('autovacuum_vacuum_scale_factor'::text)) AS autovacuum_vacuum_scale_factor,
    to_char(GREATEST(pg_stat_user_tables.last_vacuum, pg_stat_user_tables.last_autovacuum), 'DD-MON-YY HH24:MI:SS'::text) AS "LVacuum",
    to_char(GREATEST(pg_stat_user_tables.last_analyze, pg_stat_user_tables.last_autoanalyze), 'DD-MON-YY HH24:MI:SS'::text) AS "LAnalyze",
    to_char((((COALESCE(( SELECT r.v[1] AS v
           FROM regexp_matches((pg_class.reloptions)::text, 'autovacuum_vacuum_threshold=(d+)'::text) r(v)
         LIMIT 1), current_setting('autovacuum_vacuum_threshold'::text)))::bigint)::double precision + (((COALESCE(( SELECT r.v[1] AS v
           FROM regexp_matches((pg_class.reloptions)::text, 'autovacuum_vacuum_scale_factor=(d+)'::text) r(v)
         LIMIT 1), current_setting('autovacuum_vacuum_scale_factor'::text)))::numeric)::double precision * pg_class.reltuples)), '9G999G999G999'::text) AS av_threshold,
        CASE
            WHEN ((((COALESCE(( SELECT r.v[1] AS v
               FROM regexp_matches((pg_class.reloptions)::text, 'autovacuum_vacuum_threshold=(d+)'::text) r(v)
             LIMIT 1), current_setting('autovacuum_vacuum_threshold'::text)))::bigint)::double precision + (((COALESCE(( SELECT r.v[1] AS v
               FROM regexp_matches((pg_class.reloptions)::text, 'autovacuum_vacuum_scale_factor=(d+)'::text) r(v)
             LIMIT 1), current_setting('autovacuum_vacuum_scale_factor'::text)))::numeric)::double precision * pg_class.reltuples)) < (pg_stat_user_tables.n_dead_tup)::double precision) THEN 'Due To Run'::text
            ELSE ''::text
        END AS expect_av,
    COALESCE(( SELECT 'Y'::text
           FROM pg_publication_tables p
          WHERE ((p.schemaname = pg_stat_user_tables.schemaname) AND (p.tablename = pg_class.relname))
         LIMIT 1), 'N'::text) AS "Pubs",
               (pg_stat_get_live_tuples(pg_class.oid) != 0 AND  NOT EXISTS (SELECT 1 FROM pg_statistic WHERE starelid=pg_class.oid))   "MissingStats"
   FROM (((pg_class LEFT JOIN pg_catalog.pg_namespace n ON n.oid = pg_class.relnamespace
     JOIN pg_tables ON ((pg_class.oid = (((((pg_tables.schemaname)::text || '.'::text) || (pg_tables.tablename)::text))::regclass)::oid)))
     LEFT JOIN pg_stat_user_tables ON (((pg_tables.schemaname = pg_stat_user_tables.schemaname) AND (pg_tables.tablename = pg_stat_user_tables.relname))))
     LEFT JOIN bloat_data bloat_data(databasename, schemaname, tablename, can_estimate, table_bytes, table_mb, expected_bytes, expected_mb, pct_bloat, bloatbytes, table_bytes_1, expected_bytes_1, est_rows) ON (((pg_stat_user_tables.schemaname = bloat_data.schemaname) AND (pg_stat_user_tables.relname = bloat_data.tablename) AND bloat_data.can_estimate)))
     where pg_class.relkind IN ('r','p','') AND  n.nspname <> 'pg_catalog'
      AND n.nspname !~ '^pg_toast'
      AND n.nspname <> 'information_schema';

ALTER TABLE ONLY planstats.plan_table
    ADD CONSTRAINT plan_table_pkey PRIMARY KEY (planid);

create extension if not exists pg_stat_statements;

--Commented as it need pgstattuple extensions on getting bloat information.
/*CREATE VIEW planstats.vw_index_stats_tuple AS
 SELECT schemaname AS "Sname",
    relname,
    indexrelname,
    pg_size_pretty(pg_table_size(((((((schemaname)::text || '.'::text) || (indexrelname)::text))::regclass)::oid)::regclass)) AS "Size",
    to_char(last_idx_scan, 'DD-MON-YY HH24:MI:SS'::text) AS "LScan",
    idx_scan AS "Scan",
    idx_tup_read AS "TRead",
    idx_tup_fetch AS "TFetch",
        CASE
            WHEN ((EXISTS ( SELECT
               FROM pg_extension e
              WHERE (e.extname = 'pgstattuple'::name))) AND (EXISTS ( SELECT
               FROM pg_am
              WHERE ((pg_am.amname = 'btree'::name) AND (pg_am.oid = ( SELECT pg_class.relam
                       FROM pg_class
                      WHERE (pg_class.oid = (((((pg_stat_user_indexes.schemaname)::text || '.'::text) || (pg_stat_user_indexes.indexrelname)::text))::regclass)::oid))))))) THEN ( SELECT pgstatindex.leaf_fragmentation
               FROM public.pgstatindex((((pg_stat_user_indexes.schemaname)::text || '.'::text) || (pg_stat_user_indexes.indexrelname)::text)) pgstatindex(version, tree_level, index_size, root_block_no, internal_pages, leaf_pages, empty_pages, deleted_pages, avg_leaf_density, leaf_fragmentation))
            ELSE NULL::double precision
        END AS "IdxBloat",
    ( SELECT TRIM(BOTH FROM regexp_replace(idx.indexdef, (((((('(CREATE|INDEX|ON|USING|'::text || (idx.indexname)::text) || '|'::text) || (idx.schemaname)::text) || '.'::text) || (idx.tablename)::text) || ')'::text), ''::text, 'gi'::text)) AS btrim
           FROM pg_indexes idx
          WHERE ((idx.schemaname = pg_stat_user_indexes.schemaname) AND (idx.tablename = pg_stat_user_indexes.relname) AND (idx.indexname = pg_stat_user_indexes.indexrelname))) AS "Details"
   FROM pg_stat_user_indexes;
*/
