--
-- PostgreSQL database dump
--

-- Dumped from database version 16.3
-- Dumped by pg_dump version 16.2

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


CREATE FUNCTION planstats.run_plan_analyze(text, OUT planid integer, OUT queryid bigint) RETURNS record
    LANGUAGE plpgsql SECURITY DEFINER
    SET "pg_stat_statements.track" TO 'all'
    SET "pg_stat_statements.track_planning" TO 'on'
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


CREATE FUNCTION planstats.run_plan_explain(text, OUT planid integer, OUT queryid bigint) RETURNS record
    LANGUAGE plpgsql SECURITY DEFINER
    SET "pg_stat_statements.track_planning" TO 'on'
    SET client_min_messages TO 'warning'
    AS $_$
declare 
var1 text := '';
var2 text;
i text;

begin

IF current_setting('server_version')::real::int >= 16 THEN

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
