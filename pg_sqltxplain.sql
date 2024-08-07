\set VERBOSITY terse
\pset footer off

set search_path to planstats,public;

\if :{?query_id}
\if :{?pg_stat_statements}
select explainplan.planid , pg_stat_statements.queryid from pg_stat_statements , lateral planstats.run_plan_explain(query) as explainplan where pg_stat_statements.queryid =:query_id
\gset
\else
select queryid::text  as queryid from planstats.plan_table where planid = (select max(planid) from planstats.plan_table where queryid = :query_id)
\gset

select max(planid) as planid from planstats.plan_table where queryid = :query_id
\gset
\endif
\else
select queryid::text  as queryid from planstats.plan_table where planid = (select max(planid) from plan_table)
\gset

select max(planid) as planid from planstats.plan_table 
\gset

\endif

select 'pg_sqltxplain' || '_' || abs((:'queryid')::bigint) || '.html' as htmlfile 
\gset

\pset tuples_only off
\o :htmlfile
\qecho <head>	
\qecho <meta http-equiv="Content-Type" content="text/html; charset=US-ASCII">
\qecho <meta name="generator" content="PSQL">
\qecho  <title>PostgreSQL-pg_sqltxplain</title>
\qecho  <style type='text/css'> .tooltip-container{position:relative;display:inline;cursor:pointer}.tooltip-content{visibility:hidden;position:absolute;left:100%;top:50%;transform:translateY(-50%);background-color:#f9f9f9;border:1px solid #ddd;padding:10px;border-radius:4px;white-space:nowrap;opacity:0;transition:opacity .3s,visibility .3s;z-index:1000}.tooltip-container:hover .tooltip-content{visibility:visible;opacity:1}.tooltip-table{border-collapse:collapse;font-size:.9em}.tooltip-table th,.tooltip-table td{border:1px solid #ddd;padding:4px 8px;text-align:left}.tooltip-table th{background-color:#f2f2f2;font-weight:700} .body {font:11pt Arial,Helvetica,sans-serif; color:black; background:White;} p {font:13pt Arial,Helvetica,sans-serif; color:black; background:White;} table,tr,td {font:12pt Arial,Helvetica,sans-serif; color:Black; background:#f7f7e7; padding:0px 0px 0px 0px; margin:0px 0px 0px 0px;} th {font:bold 10pt Arial,Helvetica,sans-serif; color:#336699; background:#cccc99; padding:0px 0px 0px 0px;} h1 {font:16pt Arial,Helvetica,Geneva,sans-serif; color:#336699; background color:White; border-bottom:1px solid #cccc99; margin-top:0pt; margin-bottom:0pt; padding:0px 0px 0px 0px;- } h2 {font:bold 11pt Arial,Helvetica,Geneva,sans-serif; color:#336699; background-color:White; margin-top:4pt; margin-bottom:0pt;} a {font:9pt Arial,Helvetica,sans-serif; color:#663300; background:#ffffff; margin-top:0pt; margin-bottom:0pt; vertical-align:top;} .xplaina {font:11pt Arial,Helvetica,sans-serif; color:#663300; background:#ffffff; margin-top:0pt; margin-bottom:0pt; vertical-align:top;} .xplainattension {font:11pt Arial,Helvetica,sans-serif; color:#ff0000; background:#ffffff; font-weight: bold; margin-top:0pt; margin-bottom:0pt; vertical-align:top;}  footer {text-align: right;font-size: smaller;}</style>
\qecho </head>
\qecho <h1 style="font-family:verdana"align="center">pg_sqltxplain Report - QueryID = :queryid</h1>
\qecho <div class="table-content">	
\qecho <p style="font-family:verdana"><strong>Contents</strong></p>
\qecho <ol>
\qecho <li><a href="#Overview">Overview</a>
\qecho </li>
\qecho <li><a href="#QueryDetails">Query and Execution Plan Details</a>
      \qecho <li><a href="#Databaseobjects">Database Objects Statistics</a>
      \qecho <ol>
                \qecho <li><a href="#Databaseobjects1">Query Performance Stats</a></li>
                \qecho <li><a href="#Databaseobjects2">Table Stats</a></li>
                \qecho <li><a href="#Databaseobjects3">Index Stats</a></li>
		    \qecho <li><a href="#Databaseobjects4">Column Stats</a></li>
                \qecho <li><a href="#Databaseobjects4">Extended Stats</a></li>
                \qecho <li><a href="#Databaseobjects5">Trigger Stats</a></li>
                \qecho <li><a href="#Databaseobjects6">Functions Stats</a></li>
                \qecho </ol>
\qecho <li><a href="#DatabaseConfDetails">Additional Database and Configuration Details</a>
      \qecho <ol>
                \qecho <li><a href="#DatabaseConfDetails1">PostgreSQL Version and Database Details</a></li>
                \qecho <li><a href="#DatabaseConfDetails2">Database Settings during Executions</a></li>
                \qecho <li><a href="#DatabaseConfDetails3">Parameter Setting other then Defaults</a></li>
                \qecho <li><a href="#DatabaseConfDetails4">Execution Plan related Configuration Settings</a></li>
                \qecho </ol>
\qecho </li>
	 \qecho </ol>
\qecho </li>
\qecho </div>
\qecho <title>pg_sqltxplain Report</title>
\qecho <hr>
\qecho <p id="Overview" class="anchor"></p>
\qecho <h2 style="font-family:verdana">Overview</h2>
\qecho <h4 style="font-family:verdana;list-style-type:none">
\qecho  <li>pg_sqltxplain script gather stats for all database objects involved in the execution plan for a query.</li>
\qecho </h4>
\pset tuples_only on
select 'Report Creation Time : <b>' || date_trunc('second', clock_timestamp()::timestamp) || '</b>';
\pset tuples_only off
\pset format html
\qecho <br>
\qecho <hr>
\qecho <p id="QueryDetails" class="anchor"></p>
\qecho <h2 style="font-family:verdana">Query and Execution Plan Details</h2>
\qecho <h4>This section shows SQL details along with the underlying execution plan.</h4>
\qecho <li><a href="#Top">Top : </a><a href="#Databaseobjects">Next</a></li>
\pset format unaligned
\pset tuples_only on
\qecho <br>
\qecho <h2 style="font-family:verdana">SQL</h2>
\qecho <br>
\qecho <p id="ExecutionPlanDetailsAnchor" class="anchor"></p>
select concat_ws('','<pre>',sql,'</pre>')  as "SQLTEXT" from plan_table where planid = :planid;
\qecho <br>
\qecho <h2 style="font-family:verdana">Execution Plan</h2>
\qecho <br>
--select concat_ws('','<pre>',plainplan,'</pre>') as "Execution Plan"  from plan_table where planid = :planid;
\qecho <pre>

WITH
 plan_table as (select * from plan_table where planid = :planid),
plan_table1 as (select (unnest(string_to_array(a.e,' '))) col1, a.r , trim(a.e) ~ '^(Filter|Sort Key|Group Key|Hash Key|Presorted Key|Cache Key|Join Filter|One-Time Filter|Conflict Filter|Hash Cond|Run Condition|Index Cond|Recheck Cond|TID Cond|Merge Cond|Order By|Recheck Cond|Heap Fetches|Pre-sorted|Full-sort|Function Call|Table Function Call|Function Name|Table Function Name)' as filterinfo from plan_table ,
					 lateral unnest(string_to_array(PLAINPLAN,E'\n')) WITH ORDINALITY AS a(e,r) where planid =:planid),
tblname as (select distinct tblname.schname , tblname.objname, (tblname.schname || '.' || tblname.objname)::regclass::oid as oid from plan_table , lateral extract_info(jsonplan::jsonb,'Relation Name') as tblname),
idxname as (select distinct idxname.* from plan_table , lateral extract_info(jsonplan::jsonb,'Index Name') as idxname)
select string_agg(
	CASE 
	WHEN exists (SELECT 1 FROM tblname WHERE strpos(plan_table1.col1,(tblname.schname || '.' || tblname.objname)) > 0)
	THEN '<div class="tooltip-container"><a class ="' || case when false then 'xplainattension' else  'xplaina' end || '" href="#Databaseobjects2">' || plan_table1.col1 || '<div class="tooltip-content"><table class="tooltip-table">
				  <tr>
                    <th>SchemaName</th>
                    <th>TableName</th>
                    <th>Table_Size</th>
					<th>MissingStats</th>
                    <th>Index_Size</th>
				    <th>TablePages</th>
				    <th>LiveRows</th>
				    <th>DeadRows</th>
				  	<th>LVacuumTime</th>
				    <th>LAnalyzeTime</th>
                </tr>' ||
				  (select concat_ws('','<tr><td>',"SchemaName",'</td><td>',"TableName",'</td><td>',"Table_Size",'</td><td class="'|| case when "MissingStats" = 'Yes' then 'xplainattension' else '""' end || '">',"MissingStats",'</td><td>',"Index_Size",'</td><td>',"TablePages",'</td><td>',"LiveRows",'</td><td>',"DeadRows",
				 '</td><td>',"LVacuumTime",'</td><td>',"LAnalyzeTime",'</td></tr>')
from 
(select tbls."Sname" as "SchemaName",
tbls."relname" as "TableName", pg_size_pretty(pg_relation_size(relname::regclass)) as "Table_Size",
pg_size_pretty(pg_total_relation_size(relname::regclass) - pg_relation_size(relname::regclass)) as "Index_Size",
tbls."Pages"      as "TablePages",
tbls."Ltup"       as "LiveRows",
tbls."Dtup"       as "DeadRows",
tbls."LVacuum"    as "LVacuumTime",
tbls."LAnalyze"   as "LAnalyzeTime",
case when tbls."MissingStats" then 'Yes' else 'No' end as "MissingStats"
 from planstats.vw_table_stats_wo_bloat tbls , tblname
 where tbls.oid = tblname.oid
and exists (SELECT 1 FROM tblname WHERE strpos(plan_table1.col1,(tbls."Sname" || '.' || tbls."relname")) > 0)) alias1)
				  ||'</table></div></a></div>'
WHEN exists (SELECT 1 FROM idxname WHERE strpos(plan_table1.col1,idxname.objname) > 0)
THEN '<div class="tooltip-container"><a a class ="xplaina" href="#Databaseobjects3">' || plan_table1.col1 || '<div class="tooltip-content"><table class="tooltip-table">
				  <tr>
                    <th>SchemaName</th>
                    <th>TableName</th>
				    <th>IndexName</th>
                    <th>IndexSize</th>
                    <th>IndexScan</th>
				    <th>LastIndexScan</th>
				    <th>IndexEntryScan</th>
				    <th>TableRowsFetch</th>
				  	<th>IndexDefinition</th>
                </tr>' ||
				  (select concat_ws('','<tr><td>',"SchemaName",'</td><td>',"TableName",'</td><td>',"IndexName",'</td><td>',"IndexSize",'</td><td>',"IndexScan",'</td><td>',"LastIndexScan",'</td><td>',"IndexEntryScan",'</td><td>',"TableRowsFetch",
				 '</td><td>',"IndexDef",'</td></tr>')
from 
(select 
idx."Sname" as "SchemaName",
idx."relname" as "TableName",
idx."indexrelname" as "IndexName",
idx."Size"         as "IndexSize",
idx."Scan"         as "IndexScan",
idx."LScan"        as "LastIndexScan",
idx."TRead"        as "IndexEntryScan",
idx."TFetch"       as "TableRowsFetch",
idx."Details"      as "IndexDef"
 from planstats.VW_INDEX_STATS idx , tblname, idxname
where idx."Sname" = tblname.schname and idx.relname = tblname.objname
and idx.indexrelname = idxname.objname and strpos(plan_table1.col1,idxname.objname ) > 0 ) alias1 limit 1)
				  ||'</table></div></a></div>'
	WHEN filterinfo
THEN coalesce('<div class="tooltip-container"><a class ="xplaina" href="#Databaseobjects4">' || plan_table1.col1 || '<div class="tooltip-content"><table class="tooltip-table">
				  <tr>
				  	<th>TableName</th>
				  	<th>ColumnName</th>
                    <th>DataType</th>
                    <th>Nullable</th>
				    <th>Null Fraction</th>
				    <th>Distinct</th>
				    <th>Correlation</th>
				  	<th>Selectivity</th>
					<th>Storage Type</th>
					<th>Statistics Target</th>
                </tr>' ||
				  (select concat_ws('','<tr><td>',"TableName",'</td><td>',"ColumnName",'</td><td>',"DataType",'</td><td>',"Nullable",'</td><td>',"Null Fraction",
									'</td><td>',"Distinct",'</td><td>',"Correlation",
				 '</td><td>',"Selectivity",'</td><td>',"Storage Type",'</td><td>',"Statistics Target",'</td></tr>')
from 
(SELECT  cols."TName" as "TableName" , cols."CName" as "ColumnName" , cols."Type"       as "DataType",
cols."NULL?"      as "Nullable",
cols."Null%"      as "Null Fraction",
cols."Distnct"    as "Distinct",
cols."Cluster"    as "Correlation",
cols."Selectivity" as "Selectivity",
cols."Store"      as "Storage Type",
cols."StatTarget" as "Statistics Target"
 from planstats.VW_COLUMN_STATS cols , tblname 
	where cols.oid = tblname.oid and  strpos(split_part(plan_table1.col1,'.',2),cols."CName") > 0 limit 1) alias1 limit 1)
				  ||'</table></div></a></div>',plan_table1.col1)
else plan_table1.col1
end,' ')
from plan_table1
GROUP BY r order by r ;
\qecho </pre>
\pset format html
\pset tuples_only off
\qecho <br>
\echo Gathering Database Object Stats for Query ID(:queryid)
\qecho <hr>
\qecho <p id="Databaseobjects" class="anchor"></p>

\qecho <h2 style="font-family:verdana">Query and Object Statistics</h2>
\qecho <h4>This section shows underlying statistics of objects involve in Execution plan of the SQL.</h4>
\qecho <p id="Databaseobjects1" class="anchor"></p>
\qecho <h2>Performance Metrics - pg_stats_statements </h2>
\qecho <br>

\qecho <li><a href="#QueryDetails">Previous : </a><a href="#ExecutionPlanDetailsAnchor">Top : </a><a href="#Databaseobjects2">Next</a></li>
\qecho <h4>This section shows the underlying runtime execution stats of SQL.</h4>

SELECT        queryid as "QueryID",
              round(mean_plan_time::numeric, 2) as  "Mean_Planning_Time",
              round(mean_exec_time::numeric, 2) AS  "Mean_Execution_Time",
              round(stddev_exec_time::numeric, 2) AS  "Standard_Deviation_Exec_Time",
              rows/nullif(calls,0) as "Row_Per_Exec" ,
              calls as "Calls",
              plans as "Plan Count",
              (blk_read_time+blk_write_time)/nullif(calls,0) as "Disk IO per Call",
              (shared_blks_hit+shared_blks_dirtied)/nullif(calls,0) as "Buffer IO per Call",
              temp_blks_written as "Disk Temp Usage"
FROM    pg_stat_statements
where queryid = :'queryid'
ORDER BY total_exec_time DESC;

\qecho <p id="Databaseobjects2" class="anchor"></p>
\qecho <h2>Database Table Stats Summary </h2>
\qecho <br>
\qecho <li><a href="#Databaseobjects1">Previous : </a><a href="#ExecutionPlanDetailsAnchor">Top : </a><a href="#Databaseobjects3">Next</a></li>
\qecho <h4>This section shows the underlying stats of the table referenced in the execution plan.</h4>

with plan_table as (select * from plan_table where planid = :planid), 
tblname as (select distinct (tblname.schname || '.' || tblname.objname)::regclass::oid as oid from plan_table , lateral extract_info(jsonplan::jsonb,'Relation Name') as tblname)
select distinct tbls."Sname"      as "SchemaName",
tbls.relname    as "TableName",
pg_size_pretty(pg_relation_size(relname::regclass)) as "Table_Size",
pg_size_pretty(pg_total_relation_size(relname::regclass) - pg_relation_size(relname::regclass)) as "Index_Size",
tbls."Pages"      as "TablePages",
tbls."Ltup"       as "LiveRows",
tbls."Dtup"       as "DeadRows",
tbls."MissingStats"   as "MissingStats",
tbls."Part"       as "Partition?",
tbls."BloatPCT%"  as "BloatPerc",
tbls."hot_rate" as "HOT rate",
tbls."LVacuum"    as "LVacuumTime",
tbls."LAnalyze"   as "LAnalyzeTime",
tbls."autovacuum_vacuum_threshold"   as "AVThres",
tbls."autovacuum_vacuum_scale_factor"   as "AVSclFactor",
tbls."av_threshold"   as "AVThreshold",
tbls."expect_av"   as "Expect_AV",
tbls."Pubs"       as "Pub?"
 from planstats.VW_TABLE_STATS tbls , tblname
where tbls.oid = tblname.oid  ;

\qecho <p id="Databaseobjects3" class="anchor"></p>
\qecho <h2 style="font-family:verdana">Database Index Stats Summary</h2>

\qecho <li><a href="#Databaseobjects2">Previous : </a><a href="#ExecutionPlanDetailsAnchor">Top : </a><a href="#Databaseobjects4">Next</a></li>
\qecho <h4>This section shows the underlying stats of the index referenced in the execution plan.</h4>

with plan_table as (select * from plan_table where planid = :planid), 
tblname as (select distinct tblname.* from plan_table , lateral extract_info(jsonplan::jsonb,'Relation Name') as tblname),
idxname as (select distinct idxname.* from plan_table , lateral extract_info(jsonplan::jsonb,'Index Name') as idxname)
select distinct idx."Sname"        as "SchemaName",
idx.relname      as "TableName",
idx.indexrelname as "IndexName",
idx."Size"         as "IndexSize",
idx."Scan"         as "IndexScan",
idx."LScan"        as "LastIndexScan",
idx."TRead"        as "IndexEntryScan",
idx."TFetch"       as "TableRowsFetch",
idx."Details"      as "IndexDef" from  planstats.VW_INDEX_STATS idx , tblname, idxname
where idx."Sname" = tblname.schname and idx.relname = tblname.objname
and idx.indexrelname = idxname.objname;

\qecho <p id="Databaseobjects4" class="anchor"></p>
\qecho <h2 style="font-family:verdana">Execution Plan Columns Stats Summary</h2>

\qecho <li><a href="#Databaseobjects3">Previous : </a><a href="#ExecutionPlanDetailsAnchor">Top : </a><a href="#Databaseobjects5">Next</a></li>
\qecho <h4>This section shows the underlying stats of the column referenced in the execution plan.</h4>

with plan_table as (select * from plan_table where planid = :planid), 
tblname as (select distinct tblname.* from plan_table , lateral extract_info(jsonplan::jsonb,'Relation Name') as tblname),
idxname as (select distinct idxname.* from plan_table , lateral extract_info(jsonplan::jsonb,'Index Name') as idxname),
filters as (select distinct filters.* from plan_table , lateral extract_filters(jsonplan::jsonb)  as filters)
select distinct cols."SName"      as "SchemaName",
cols."TName"      as "TableName",
cols."CName"      as "ColumnName",
cols."Type"       as "DataType",
cols."NULL?"      as "Nullable",
cols."Null%"      as "Null Fraction",
cols."Distnct"    as "Distinct",
cols."Cluster"    as "Correlation",
cols."Selectivity" as "Selectivity",
cols."Store"      as "Storage Type",
cols."Cmprssn"    as "Compression",
cols."StatTarget" as "Statistics Target",
cols."MCV"        as "Most Common Val(5)",
cols."MVF"        as "Most Common Freq(5)" 
from filters, planstats.VW_COLUMN_STATS cols , tblname
where cols."SName" = tblname.schname and cols."TName" = tblname.objname
and  filters.objname ~* cols."CName";

\qecho <p id="Databaseobjects5" class="anchor"></p>
\qecho <h2 style="font-family:verdana">Execution Plan Extended Stats Summary</h2>

\qecho <li><a href="#Databaseobjects3">Previous : </a><a href="#ExecutionPlanDetailsAnchor">Top : </a><a href="#Databaseobjects6">Next</a></li>
\qecho <h4>This section shows the underlying extended stats of the Table referenced in the execution plan.</h4>

with plan_table as (select * from plan_table where planid = :planid), 
tblname as (select distinct tblname.* from plan_table , lateral extract_info(jsonplan::jsonb,'Relation Name') as tblname),
idxname as (select distinct idxname.* from plan_table , lateral extract_info(jsonplan::jsonb,'Index Name') as idxname),
filters as (select distinct filters.* from plan_table , lateral extract_filters(jsonplan::jsonb)  as filters)
SELECT distinct
      stxnamespace::pg_catalog.regnamespace::pg_catalog.text AS "Schema",
	stxrelid :: pg_catalog.regclass as "TableName",
	stxname as "Statistics Name",
	pg_catalog.pg_get_statisticsobjdef_columns(oid) AS columns,
	CASE WHEN 'd' = any(stxkind) then 'Y' else 'N' end AS "NDistinct",
	CASE WHEN 'f' = any(stxkind) then 'Y' else 'N' end AS "Dependency",
	CASE WHEN 'm' = any(stxkind) then 'Y' else 'N' end  AS "MCV",
	stxstattarget as "Statistics Target"
FROM
	pg_catalog.pg_statistic_ext , tblname , filters , lateral unnest(string_to_array(pg_catalog.pg_get_statisticsobjdef_columns(oid),',')) as cols
WHERE stxnamespace::pg_catalog.regnamespace::pg_catalog.text = trim(tblname.schname)
and stxrelid::pg_catalog.regclass::text = trim(tblname.objname)
and filters.objname ~* trim(cols)
ORDER BY 1,2,3;

\qecho <p id="Databaseobjects6" class="anchor"></p>
\qecho <h2 style="font-family:verdana">Execution Plan Trigger Stats Summary</h2>

\qecho <li><a href="#Databaseobjects5">Previous : </a><a href="#ExecutionPlanDetailsAnchor">Top : </a><a href="#Databaseobjects7">Next</a></li>
\qecho <h4>This section shows the underlying details of triggers referenced in the execution plan, if any.</h4>

select 
    trim(substr(steps,8,strpos(steps,':')-8)) as TriggerName , 
    split_part(split_part(trim(split_part(steps,':',2)),' ',1),'=',2) as "Time" ,  
    split_part(split_part(trim(split_part(steps,':',2)),' ',2),'=',2) as "Calls" ,
    pg_trigger.tgrelid::regclass::text as "TableName",
    pg_trigger.tgfoid::regproc::text as "ProcedureName",
   replace(pg_get_triggerdef(oid),'CREATE TRIGGER '||trim(substr(steps,8,strpos(steps,':')-8))|| ' ','') as "TriggerDef"
from plan_table, lateral unnest(string_to_array(plainplan,E'\n')) steps , pg_trigger
where tgname = lower(trim(substr(steps,8,strpos(steps,':')-8)))
and planid = :planid and lower(steps) LIKE 'trigger %';

\qecho <p id="Databaseobjects7" class="anchor"></p>
\qecho <h2 style="font-family:verdana">Execution Plan Function Stats Summary</h2>

\qecho <li><a href="#Databaseobjects6">Previous : </a><a href="#ExecutionPlanDetailsAnchor">Top : </a><a href="#DatabaseConfDetails">Next</a></li>
\qecho <h4>This section shows the underlying details of functions referenced in the execution plan, but only if the <i>track_functions</i> flag is set.</h4>

with plan_table as (
	select
		*
	from
		plan_table
	where
		planid = :planid
),
filter as (
	select
		distinct filters.*
	from
		plan_table,
		lateral extract_filters(jsonplan :: jsonb) as filters
)
select
	schemaname,
	funcname,
	calls,
	total_time,
	self_time,CASE
		p.prokind
		WHEN 'a' THEN 'agg'
		WHEN 'w' THEN 'window'
		WHEN 'p' THEN 'proc'
		ELSE 'func'
	END as "Type",
	CASE
		WHEN p.provolatile = 'i' THEN 'immutable'
		WHEN p.provolatile = 's' THEN 'stable'
		WHEN p.provolatile = 'v' THEN 'volatile'
	END as "Volatility",
	CASE
		WHEN p.proparallel = 'r' THEN 'restricted'
		WHEN p.proparallel = 's' THEN 'safe'
		WHEN p.proparallel = 'u' THEN 'unsafe'
	END as "Parallel",
	l.lanname as "Language",
	objname as "Filter"
from
	pg_stat_user_functions
	inner join filter on "objname" ~* funcname
	left outer join pg_catalog.pg_proc p on p.proname OPERATOR(pg_catalog.~) ('^(' || funcname || ')$') COLLATE pg_catalog.default
	AND pg_catalog.pg_function_is_visible(p.oid)
	LEFT JOIN pg_catalog.pg_language l ON l.oid = p.prolang
	 ;

\qecho <br>
\qecho <hr>
\qecho <br>
\qecho <p id="DatabaseConfDetails" class="anchor"></p>
\qecho <h2 style="font-family:verdana">Additional Configuration and Database Details</h2>
\qecho <h4>This section shows additional database details along with must-know configurations for execution plan analysis.</h4>
\qecho <li><a href="#Databaseobjects4">Previous : </a><a href="#Top">Top : </a><a href="#DatabaseConfDetails2">Next</a></li>
\qecho <p id="DatabaseConfDetails1" class="anchor"></p>
\qecho <h2>PostgreSQL Version and Database Details</h2>
\qecho <br>
\pset footer off

select datname as "Database Name",  (regexp_matches(version(), 'PostgreSQL\s\d+\.\d+'))[1] AS version,
CASE WHEN pg_catalog.has_database_privilege(datname, 'CONNECT')
       THEN pg_catalog.pg_size_pretty(pg_catalog.pg_database_size(datname))
       ELSE 'No Access'
  END as "Size",
  blks_hit*100/(blks_hit+blks_read) as  "Hit Ratio" ,
(xact_commit*100)/nullif(xact_commit+xact_rollback,0) as xact_commit_ratio, 
(xact_rollback*100)/nullif(xact_commit+xact_rollback, 0) as xact_rollback_ratio, 
deadlocks, conflicts, temp_files as "Temp Files", pg_size_pretty(temp_bytes)  as "Total Temp"
from pg_stat_database where datname = current_database();
\qecho <br>
\qecho <li><a href="#DatabaseConfDetails1">Previous : </a><a href="#Top">Top : </a><a href="#DatabaseConfDetails3">Next</a></li>
\qecho <p id="DatabaseConfDetails2" class="anchor"></p>
\qecho <h2>Database Settings During Execution</h2>
\qecho <br>
\pset footer off

select s.key as "Execution Plan Setting", s.value as "Value" 
from planstats.plan_table  , lateral jsonb_each_text(CASE WHEN jsonplan::jsonb->0 ? 'Settings' THEN jsonplan::jsonb->0 -> 'Settings' END) as s
where planid = :planid order by 1 ;

\qecho <p id="DatabaseConfDetails3" class="anchor"></p>
\qecho <h2>Database Parameter Settings Other Than Defaults </h2>
\qecho <br>

\qecho <li><a href="#DatabaseConfDetails2">Previous : </a><a href="#Top">Top : </a><a href="#DatabaseConfDetails4">Next</a></li>
\qecho <br>
SELECT s.name AS "Parameter", pg_catalog.current_setting(s.name) AS "Value"
FROM pg_catalog.pg_settings s
WHERE s.source <> 'default' AND
      s.setting IS DISTINCT FROM s.boot_val
      and (s.name not like '%file%' and s.name not like '%directory%')
ORDER BY 1;
\qecho <br>
\qecho <p id="DatabaseConfDetails4" class="anchor"></p>
\qecho <h2>Important Configuration Settings for Execution Plan</h2>
\qecho <br>

\qecho <li><a href="#DatabaseConfDetails3">Previous : </a><a href="#Top">Top : </a></li>
\qecho <br>
SELECT s.name AS "Parameter", pg_catalog.current_setting(s.name) AS "Value"
FROM pg_catalog.pg_settings s
WHERE pg_catalog.lower(s.name) OPERATOR(pg_catalog.~) '^(work_mem|random_page_cost|seq_page_cost|default_statistics_target|hash_mem_multiplier|temp_buffers|plan_cache_mode|from_collapse_limit|join_collapse_limit|max_parallel_workers|max_parallel_workers_per_gather|min_parallel_table_scan_size)$' COLLATE pg_catalog.default
ORDER BY 1;
\qecho <br>
\qecho <br>

\qecho <footer>
\qecho  Created by DataCloudGaze Consulting<br>
\qecho   <a href="mailto:contact@datacloudgaze.com">Report Issue - contact@datacloudgaze.com</a><br>
\qecho   <a href="https://www.datacloudgaze.com/">About Us</a>
\qecho </footer>
\qecho <h1 style="font-family:verdana"align="center"><u>End Report </u></h1>
\echo Underlying Statistics curated for Query(:queryid) - Output File :htmlfile 

