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
select 'dalibo' || '_' || abs((:'queryid')::bigint) || '.html' as htmlfile 
\gset

\o :htmlfile
\pset footer off
\pset tuples_only on
\qecho <!DOCTYPE html>
\qecho <html lang="en">
\qecho <head>
\qecho   <meta charset="UTF-8">
\qecho   <meta name="viewport" content="width=device-width, initial-scale=1.0">
\qecho   <title>PostgreSQL Query Plan Viewer - Dalibo</title>
\qecho   <script src="https://unpkg.com/vue@3.2.45/dist/vue.global.prod.js"></script>
\qecho   <script src="https://unpkg.com/pev2/dist/pev2.umd.js"></script>
\qecho   <link href="https://unpkg.com/bootstrap@5.3.2/dist/css/bootstrap.min.css" rel="stylesheet"/>
\qecho   <link rel="stylesheet" href="https://unpkg.com/pev2/dist/style.css"/>
\qecho </head>
\qecho <body>
\qecho   <div id="app" class="container-fluid mt-auto">
\qecho     <pev2 :plan-source="plan" :plan-query="query"  />
\qecho   </div>
\qecho 
\qecho   <script>
\qecho     const { createApp } = Vue;
\qecho     const app = createApp({
\qecho       data() {
\qecho         return {
\pset format unaligned
select concat_ws('','query:','`',sql,'`,')  from plan_table where planid = :planid;
select concat_ws('','plan:','`',plainplan,'`')  from plan_table where planid = :planid;
\qecho         }
\qecho       },
\qecho     });
\qecho     app.component("pev2", pev2.Plan);
\qecho     app.mount("#app");
\qecho   </script>
\echo
\echo Dalibo Plan is generated for Query(:queryid)
\qecho </body>
\qecho </html>
