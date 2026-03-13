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

select exists(select 1 from pg_extension where extname = 'pg_stat_statements') as has_pgss
\gset

select (current_setting('server_version_num')::int >= 170000) as pg17plus
\gset

\pset tuples_only off
\o :htmlfile
\qecho <!DOCTYPE html>
\qecho <html lang="en">
\qecho <head>
\qecho <meta charset="UTF-8">
\qecho <meta name="viewport" content="width=device-width, initial-scale=1.0">
\qecho <meta name="generator" content="PSQL">
\qecho  <title>PostgreSQL-pg_sqltxplain</title>
\qecho  <style type="text/css">
\qecho :root {
\qecho   --bg-primary: #f5f5f7;
\qecho   --bg-secondary: #ffffff;
\qecho   --bg-tertiary: #e8e8ed;
\qecho   --text-primary: #1d1d1f;
\qecho   --text-secondary: #6e6e73;
\qecho   --text-heading: #1d1d1f;
\qecho   --link-color: #0066cc;
\qecho   --link-hover: #0055aa;
\qecho   --border-color: #d2d2d7;
\qecho   --border-light: #e8e8ed;
\qecho   --table-header-bg: #e8e8ed;
\qecho   --table-header-text: #1d1d1f;
\qecho   --table-row-alt: #fafafa;
\qecho   --table-row-bg: #ffffff;
\qecho   --pre-bg: #1e1e1e;
\qecho   --pre-text: #d4d4d4;
\qecho   --window-bar-bg: #e8e8ed;
\qecho   --window-bar-border: #d2d2d7;
\qecho   --card-shadow: 0 1px 3px rgba(0,0,0,0.08);
\qecho   --card-shadow-hover: 0 2px 8px rgba(0,0,0,0.12);
\qecho   --nav-bg: #f0f0f5;
\qecho   --badge-cat-bg: #607d8b;
\qecho   --rec-high-bg: #fff0f0;
\qecho   --rec-high-border: #cc0000;
\qecho   --rec-medium-bg: #fff8f0;
\qecho   --rec-medium-border: #ff9800;
\qecho   --rec-low-bg: #f0f7ff;
\qecho   --rec-low-border: #2196f3;
\qecho   --rec-none-bg: #f0faf0;
\qecho   --rec-none-border: #4caf50;
\qecho   --rec-none-text: #2e7d32;
\qecho   --tooltip-bg: #ffffff;
\qecho   --tooltip-border: #d2d2d7;
\qecho   --tooltip-shadow: 0 4px 12px rgba(0,0,0,0.15);
\qecho   --footer-bg: #f5f5f7;
\qecho   --section-gap: 24px;
\qecho }
\qecho body.dark {
\qecho   --bg-primary: #1e1e1e;
\qecho   --bg-secondary: #282828;
\qecho   --bg-tertiary: #333333;
\qecho   --text-primary: #e0e0e0;
\qecho   --text-secondary: #a0a0a0;
\qecho   --text-heading: #f0f0f0;
\qecho   --link-color: #64d2ff;
\qecho   --link-hover: #40c4ff;
\qecho   --border-color: #444444;
\qecho   --border-light: #383838;
\qecho   --table-header-bg: #333333;
\qecho   --table-header-text: #e0e0e0;
\qecho   --table-row-alt: #2a2a2a;
\qecho   --table-row-bg: #282828;
\qecho   --pre-bg: #0d0d0d;
\qecho   --pre-text: #d4d4d4;
\qecho   --window-bar-bg: #2a2a2a;
\qecho   --window-bar-border: #444444;
\qecho   --card-shadow: 0 1px 3px rgba(0,0,0,0.3);
\qecho   --card-shadow-hover: 0 2px 8px rgba(0,0,0,0.4);
\qecho   --nav-bg: #2a2a2a;
\qecho   --badge-cat-bg: #78909c;
\qecho   --rec-high-bg: #3a1a1a;
\qecho   --rec-high-border: #ff4444;
\qecho   --rec-medium-bg: #3a2e1a;
\qecho   --rec-medium-border: #ffb74d;
\qecho   --rec-low-bg: #1a2a3a;
\qecho   --rec-low-border: #64b5f6;
\qecho   --rec-none-bg: #1a3a1a;
\qecho   --rec-none-border: #66bb6a;
\qecho   --rec-none-text: #81c784;
\qecho   --tooltip-bg: #333333;
\qecho   --tooltip-border: #555555;
\qecho   --tooltip-shadow: 0 4px 12px rgba(0,0,0,0.5);
\qecho   --footer-bg: #1e1e1e;
\qecho   --section-gap: 24px;
\qecho }
\qecho *,*::before,*::after { box-sizing: border-box; }
\qecho body {
\qecho   font-family: "SF Mono", Menlo, Monaco, Consolas, monospace;
\qecho   font-size: 10pt;
\qecho   color: var(--text-primary);
\qecho   background: var(--bg-primary);
\qecho   margin: 0;
\qecho   padding: 0;
\qecho   line-height: 1.6;
\qecho }
\qecho main {
\qecho   max-width: 1200px;
\qecho   margin: 0 auto;
\qecho   padding: 0 20px 40px 20px;
\qecho }
\qecho h1 {
\qecho   font-size: 16pt;
\qecho   color: var(--text-heading);
\qecho   margin: 0;
\qecho   padding: 16px 0;
\qecho   text-align: center;
\qecho   border-bottom: 1px solid var(--border-color);
\qecho }
\qecho h2 {
\qecho   font-size: 12pt;
\qecho   color: var(--text-heading);
\qecho   margin: var(--section-gap) 0 8px 0;
\qecho   padding: 0;
\qecho }
\qecho h4 {
\qecho   font-size: 9pt;
\qecho   color: var(--text-secondary);
\qecho   font-weight: normal;
\qecho   margin: 4px 0 12px 0;
\qecho }
\qecho p {
\qecho   font-size: 10pt;
\qecho   color: var(--text-primary);
\qecho   background: transparent;
\qecho }
\qecho a {
\qecho   font-size: 9pt;
\qecho   color: var(--link-color);
\qecho   text-decoration: none;
\qecho }
\qecho a:hover { color: var(--link-hover); text-decoration: underline; }
\qecho .xplaina {
\qecho   font-size: 10pt;
\qecho   color: var(--link-color);
\qecho   text-decoration: none;
\qecho   border-bottom: 1px dotted var(--link-color);
\qecho }
\qecho .xplainattension {
\qecho   font-size: 10pt;
\qecho   color: #ff3b30;
\qecho   font-weight: bold;
\qecho   text-decoration: none;
\qecho   border-bottom: 1px dotted #ff3b30;
\qecho }
\qecho /* Window chrome bar */
\qecho .window-bar {
\qecho   display: flex;
\qecho   align-items: center;
\qecho   padding: 10px 16px;
\qecho   background: var(--window-bar-bg);
\qecho   border-bottom: 1px solid var(--window-bar-border);
\qecho   position: sticky;
\qecho   top: 0;
\qecho   z-index: 100;
\qecho }
\qecho .dot {
\qecho   width: 12px;
\qecho   height: 12px;
\qecho   border-radius: 50%;
\qecho   display: inline-block;
\qecho   margin-right: 8px;
\qecho }
\qecho .dot.red { background: #ff5f57; }
\qecho .dot.yellow { background: #febc2e; }
\qecho .dot.green { background: #28c840; }
\qecho .window-title {
\qecho   flex: 1;
\qecho   text-align: center;
\qecho   font-size: 10pt;
\qecho   color: var(--text-secondary);
\qecho   font-weight: 600;
\qecho }
\qecho #theme-btn {
\qecho   font-family: "SF Mono", Menlo, Monaco, Consolas, monospace;
\qecho   font-size: 9pt;
\qecho   padding: 4px 14px;
\qecho   border: 1px solid var(--border-color);
\qecho   border-radius: 6px;
\qecho   background: var(--bg-secondary);
\qecho   color: var(--text-primary);
\qecho   cursor: pointer;
\qecho   transition: background 0.2s, color 0.2s, border-color 0.2s;
\qecho }
\qecho #theme-btn:hover {
\qecho   background: var(--bg-tertiary);
\qecho }
\qecho /* Table of contents */
\qecho .toc {
\qecho   background: var(--bg-secondary);
\qecho   border: 1px solid var(--border-color);
\qecho   border-radius: 8px;
\qecho   padding: 16px 24px;
\qecho   margin: var(--section-gap) 0;
\qecho   box-shadow: var(--card-shadow);
\qecho }
\qecho .toc strong { color: var(--text-heading); font-size: 11pt; }
\qecho .toc ol { padding-left: 20px; margin: 8px 0 0 0; }
\qecho .toc li { margin: 4px 0; list-style-type: decimal; }
\qecho .toc a { font-size: 9pt; }
\qecho /* Tables - psql HTML output */
\qecho section { overflow-x: auto; }
\qecho table {
\qecho   width: auto;
\qecho   border-collapse: collapse;
\qecho   font-size: 9pt;
\qecho   background: var(--bg-secondary);
\qecho   border: 1px solid var(--border-color);
\qecho   border-radius: 8px;
\qecho   overflow: hidden;
\qecho   box-shadow: var(--card-shadow);
\qecho   margin: 8px 0;
\qecho }
\qecho th {
\qecho   background: var(--table-header-bg);
\qecho   color: var(--table-header-text);
\qecho   font-weight: 600;
\qecho   font-size: 9pt;
\qecho   padding: 10px 12px;
\qecho   text-align: left;
\qecho   white-space: nowrap;
\qecho   border-bottom: 2px solid var(--border-color);
\qecho }
\qecho td {
\qecho   padding: 8px 12px;
\qecho   border-bottom: 1px solid var(--border-light);
\qecho   color: var(--text-primary);
\qecho   background: var(--table-row-bg);
\qecho   white-space: nowrap;
\qecho }
\qecho tr:nth-child(even) td { background: var(--table-row-alt); }
\qecho tr:hover td { background: var(--bg-tertiary); }
\qecho /* Pre blocks for execution plan */
\qecho pre {
\qecho   background: var(--pre-bg);
\qecho   color: var(--pre-text);
\qecho   padding: 16px;
\qecho   border-radius: 8px;
\qecho   overflow-x: auto;
\qecho   font-family: "SF Mono", Menlo, Monaco, Consolas, monospace;
\qecho   font-size: 9pt;
\qecho   line-height: 1.5;
\qecho   border: 1px solid var(--border-color);
\qecho   box-shadow: var(--card-shadow);
\qecho }
\qecho pre a, pre .xplaina { color: #64d2ff; border-bottom-color: #64d2ff; }
\qecho pre .xplainattension { color: #ff6b6b; border-bottom-color: #ff6b6b; }
\qecho /* Tooltip styles */
\qecho .tooltip-container {
\qecho   position: relative;
\qecho   display: inline;
\qecho   cursor: pointer;
\qecho }
\qecho .tooltip-content {
\qecho   visibility: hidden;
\qecho   position: absolute;
\qecho   left: 100%;
\qecho   top: 50%;
\qecho   transform: translateY(-50%);
\qecho   background-color: var(--tooltip-bg);
\qecho   border: 1px solid var(--tooltip-border);
\qecho   padding: 12px;
\qecho   border-radius: 8px;
\qecho   white-space: nowrap;
\qecho   opacity: 0;
\qecho   transition: opacity 0.2s, visibility 0.2s;
\qecho   z-index: 1000;
\qecho   box-shadow: var(--tooltip-shadow);
\qecho   max-width: 600px;
\qecho   overflow-x: auto;
\qecho }
\qecho .tooltip-container:hover .tooltip-content {
\qecho   visibility: visible;
\qecho   opacity: 1;
\qecho }
\qecho .tooltip-table {
\qecho   border-collapse: collapse;
\qecho   font-size: 8pt;
\qecho   box-shadow: none;
\qecho   border: none;
\qecho   margin: 0;
\qecho }
\qecho .tooltip-table th {
\qecho   background-color: var(--table-header-bg);
\qecho   color: var(--table-header-text);
\qecho   font-size: 8pt;
\qecho   padding: 4px 8px;
\qecho }
\qecho .tooltip-table td {
\qecho   border: 1px solid var(--border-light);
\qecho   padding: 4px 8px;
\qecho   font-size: 8pt;
\qecho }
\qecho /* Section navigation */
\qecho .section-nav {
\qecho   display: flex;
\qecho   gap: 12px;
\qecho   padding: 6px 12px;
\qecho   background: var(--nav-bg);
\qecho   border-radius: 6px;
\qecho   margin: 8px 0;
\qecho   font-size: 9pt;
\qecho   list-style: none;
\qecho }
\qecho .section-nav a { font-size: 9pt; }
\qecho /* Recommendations */
\qecho .recommendations-section { margin: 12px 0; }
\qecho .rec-high {
\qecho   background-color: var(--rec-high-bg);
\qecho   border-left: 4px solid var(--rec-high-border);
\qecho   padding: 10px 14px;
\qecho   margin: 8px 0;
\qecho   border-radius: 0 6px 6px 0;
\qecho }
\qecho .rec-medium {
\qecho   background-color: var(--rec-medium-bg);
\qecho   border-left: 4px solid var(--rec-medium-border);
\qecho   padding: 10px 14px;
\qecho   margin: 8px 0;
\qecho   border-radius: 0 6px 6px 0;
\qecho }
\qecho .rec-low {
\qecho   background-color: var(--rec-low-bg);
\qecho   border-left: 4px solid var(--rec-low-border);
\qecho   padding: 10px 14px;
\qecho   margin: 8px 0;
\qecho   border-radius: 0 6px 6px 0;
\qecho }
\qecho .rec-title { font-weight: bold; font-size: 10pt; color: var(--text-primary); }
\qecho .rec-detail { font-size: 9pt; color: var(--text-secondary); margin-top: 4px; }
\qecho .rec-action { font-size: 9pt; color: var(--link-color); margin-top: 4px; font-style: italic; }
\qecho .rec-badge {
\qecho   display: inline-block;
\qecho   padding: 2px 8px;
\qecho   border-radius: 4px;
\qecho   font-size: 8pt;
\qecho   font-weight: bold;
\qecho   color: white;
\qecho   margin-right: 6px;
\qecho }
\qecho .badge-high { background-color: #cc0000; }
\qecho .badge-medium { background-color: #ff9800; }
\qecho .badge-low { background-color: #2196f3; }
\qecho .rec-none {
\qecho   padding: 14px;
\qecho   background-color: var(--rec-none-bg);
\qecho   border-left: 4px solid var(--rec-none-border);
\qecho   font-size: 10pt;
\qecho   color: var(--rec-none-text);
\qecho   border-radius: 0 6px 6px 0;
\qecho }
\qecho /* Plan wrapper with maximize */
\qecho .plan-wrapper {
\qecho   position: relative;
\qecho   border: 1px solid var(--border-color);
\qecho   border-radius: 8px;
\qecho   background: var(--pre-bg);
\qecho   overflow: hidden;
\qecho   margin: 12px 0;
\qecho }
\qecho .plan-wrapper pre {
\qecho   margin: 0;
\qecho   border: none;
\qecho   border-radius: 0;
\qecho   box-shadow: none;
\qecho   max-height: 600px;
\qecho   overflow: auto;
\qecho }
\qecho .plan-wrapper.fullscreen {
\qecho   position: fixed;
\qecho   top: 0;
\qecho   left: 0;
\qecho   width: 100vw;
\qecho   height: 100vh;
\qecho   z-index: 9999;
\qecho   border: none;
\qecho   border-radius: 0;
\qecho }
\qecho .plan-wrapper.fullscreen pre {
\qecho   max-height: 100vh;
\qecho   height: calc(100vh - 38px);
\qecho }
\qecho .plan-toolbar {
\qecho   display: flex;
\qecho   justify-content: flex-end;
\qecho   padding: 4px 8px;
\qecho   background: var(--window-bar-bg);
\qecho   border-bottom: 1px solid var(--border-color);
\qecho }
\qecho .plan-btn {
\qecho   font-family: "SF Mono", Menlo, Monaco, Consolas, monospace;
\qecho   font-size: 9pt;
\qecho   padding: 4px 14px;
\qecho   border: 1px solid var(--border-color);
\qecho   border-radius: 6px;
\qecho   background: var(--bg-secondary);
\qecho   color: var(--text-primary);
\qecho   cursor: pointer;
\qecho   transition: background 0.2s;
\qecho }
\qecho .plan-btn:hover { background: var(--bg-tertiary); }
\qecho /* Footer */
\qecho footer {
\qecho   text-align: center;
\qecho   font-size: 9pt;
\qecho   color: var(--text-secondary);
\qecho   padding: 20px 0;
\qecho   margin-top: 40px;
\qecho   border-top: 1px solid var(--border-color);
\qecho   background: var(--footer-bg);
\qecho }
\qecho footer a { color: var(--link-color); }
\qecho /* Section cards */
\qecho section {
\qecho   background: var(--bg-secondary);
\qecho   border: 1px solid var(--border-color);
\qecho   border-radius: 8px;
\qecho   padding: 16px 20px;
\qecho   margin: var(--section-gap) 0;
\qecho   box-shadow: var(--card-shadow);
\qecho }
\qecho section table { box-shadow: none; }
\qecho /* Anchor fix for sticky header */
\qecho .anchor { scroll-margin-top: 60px; }
\qecho  </style>
\qecho <script>function toggleTheme(){var b=document.body;var t=document.getElementById("theme-btn");if(b.classList.contains("dark")){b.classList.remove("dark");t.textContent="Night Mode";}else{b.classList.add("dark");t.textContent="Day Mode";}}</script>
\qecho <script>function togglePlanFullscreen(){var w=document.getElementById("plan-wrap");var b=document.getElementById("plan-btn");if(w.classList.contains("fullscreen")){w.classList.remove("fullscreen");b.textContent="Full Screen";document.body.style.overflow="";}else{w.classList.add("fullscreen");b.textContent="Exit Full Screen";document.body.style.overflow="hidden";}}</script>
\qecho </head>
\qecho <body>
\qecho <div class="window-bar">
\qecho   <span class="dot red"></span><span class="dot yellow"></span><span class="dot green"></span>
\qecho   <span class="window-title">pg_sqltxplain</span>
\qecho   <button id="theme-btn" onclick="toggleTheme()">Night Mode</button>
\qecho </div>
\qecho <main>
\qecho <header data-section="report-header">
\qecho <h1>pg_sqltxplain Report - QueryID = :queryid</h1>
\qecho </header>
\qecho <nav data-section="toc" class="toc">
\qecho <strong>Contents</strong>
\qecho <ol>
\qecho <li><a href="#Overview">Overview</a></li>
\qecho <li><a href="#QueryDetails">Query and Execution Plan Details</a></li>
\qecho <li><a href="#Recommendations">Expert Recommendations</a></li>
\qecho <li><a href="#Databaseobjects">Database Objects Statistics</a>
\qecho <ol>
\qecho <li><a href="#Databaseobjects1">Query Performance Stats</a></li>
\qecho <li><a href="#Databaseobjects2">Table Stats</a></li>
\qecho <li><a href="#Databaseobjects3">Index Stats</a></li>
\qecho <li><a href="#Databaseobjects4">Column Stats</a></li>
\qecho <li><a href="#Databaseobjects5">Extended Stats</a></li>
\qecho <li><a href="#Databaseobjects6">Trigger Stats</a></li>
\qecho <li><a href="#Databaseobjects7">Functions Stats</a></li>
\qecho </ol>
\qecho </li>
\qecho <li><a href="#DatabaseConfDetails">Additional Database and Configuration Details</a>
\qecho <ol>
\qecho <li><a href="#DatabaseConfDetails1">PostgreSQL Version and Database Details</a></li>
\qecho <li><a href="#DatabaseConfDetails2">Database Settings during Executions</a></li>
\qecho <li><a href="#DatabaseConfDetails3">Parameter Setting other than Defaults</a></li>
\qecho <li><a href="#DatabaseConfDetails4">Execution Plan related Configuration Settings</a></li>
\qecho </ol>
\qecho </li>
\qecho </ol>
\qecho </nav>
\qecho <section data-section="overview" id="Overview" class="anchor">
\qecho <h2>Overview</h2>
\qecho <h4>pg_sqltxplain script gathers stats for all database objects involved in the execution plan for a query.</h4>
\pset tuples_only on
select 'Report Creation Time : <b>' || date_trunc('second', clock_timestamp()::timestamp) || '</b>';
\pset tuples_only off
\pset format html
\qecho </section>
\qecho <section data-section="sql-query" id="QueryDetails" class="anchor">
\qecho <h2>Query and Execution Plan Details</h2>
\qecho <h4>This section shows SQL details along with the underlying execution plan.</h4>
\qecho <nav class="section-nav"><a href="#Overview">Previous</a> <a href="#report-header">Top</a> <a href="#Recommendations">Next</a></nav>
\pset format unaligned
\pset tuples_only on
\qecho <h2>SQL</h2>
select concat_ws('','<pre>',sql,'</pre>')  as "SQLTEXT" from plan_table where planid = :planid;
\qecho </section>
\qecho <section data-section="execution-plan" id="ExecutionPlanDetailsAnchor" class="anchor">
\qecho <h2>Execution Plan</h2>
\qecho <div id="plan-wrap" class="plan-wrapper">
\qecho <div class="plan-toolbar">
\qecho <button id="plan-btn" class="plan-btn" onclick="togglePlanFullscreen()">Full Screen</button>
\qecho </div>
\qecho <pre>

WITH
 plan_table as (select * from plan_table where planid = :planid),
node_metrics as (
  select n.node_id, n.depth,
    n.node->>'Node Type' as node_type,
    n.node->>'Relation Name' as relation_name,
    n.node->>'Schema' as schema_name,
    n.node->>'Filter' as filter_expr,
    n.node->>'Join Filter' as join_filter_expr,
    n.node->>'Plan Rows' as plan_rows,
    n.node->>'Actual Rows' as actual_rows,
    n.node->>'Rows Removed by Filter' as rows_removed_filter,
    n.node->>'Rows Removed by Join Filter' as rows_removed_join_filter,
    n.node->>'Heap Fetches' as heap_fetches,
    n.node->>'Sort Space Used' as sort_space_used,
    n.node->>'Sort Space Type' as sort_space_type,
    n.node->>'Sort Key' as sort_key,
    n.node->>'Hash Batches' as hash_batches,
    n.node->>'Original Hash Batches' as original_hash_batches,
    n.node->>'Hash Buckets' as hash_buckets,
    n.node->>'Shared Hit Blocks' as shared_hit_blocks,
    n.node->>'Shared Read Blocks' as shared_read_blocks,
    (n.node->>'Startup Cost')::numeric as startup_cost,
    (n.node->>'Total Cost')::numeric as total_cost
  from plan_table, lateral planstats.extract_all_nodes(jsonplan::jsonb) n
),
plan_table1 as (select (unnest(string_to_array(a.e,' '))) col1, a.r ,
  trim(a.e) ~ '^(Filter|Sort Key|Group Key|Hash Key|Presorted Key|Cache Key|Join Filter|One-Time Filter|Conflict Filter|Hash Cond|Run Condition|Index Cond|Recheck Cond|TID Cond|Merge Cond|Order By|Recheck Cond|Heap Fetches|Pre-sorted|Full-sort|Function Call|Table Function Call|Function Name|Table Function Name)' as filterinfo,
  trim(a.e) as full_line,
  trim(a.e) ~ '^Rows Removed by (Filter|Join Filter):' as rows_removed_line,
  trim(a.e) ~ '^Heap Fetches:' as heap_fetches_line,
  trim(a.e) ~ '^(Sort Space Used:|Sort Method:)' as sort_space_line,
  trim(a.e) ~ '^Hash Batches:' as hash_batches_line,
  False as buffers_line --Commented as logic need to be re-evaluted
  from plan_table ,
  lateral unnest(string_to_array(PLAINPLAN,E'\n')) WITH ORDINALITY AS a(e,r) where planid =:planid),
hdr_lines as (
  select hdr_r, full_line as hdr_full_line,
    substring(full_line from 'cost=(\d+\.?\d*)\.\.') as text_startup,
    substring(full_line from 'cost=\d+\.?\d*\.\.(\d+\.?\d*)') as text_total,
    substring(full_line from '\(cost=\d+\.?\d*\.\.\d+\.?\d* rows=(\d+) width=') as text_plan_rows,
    substring(full_line from 'actual.*rows=(\d+\.?\d*)') as text_actual_rows
  from (select distinct r as hdr_r, full_line from plan_table1 where full_line like '%cost=%') sub
),
line_node_map as (
  select p.line_num, nm.*, hl2.text_plan_rows, hl2.text_actual_rows
  from (
    select distinct r as line_num,
      (select max(hl.hdr_r) from hdr_lines hl where hl.hdr_r <= plan_table1.r) as hdr_r
    from plan_table1
  ) p
  join hdr_lines hl2 on hl2.hdr_r = p.hdr_r
  join node_metrics nm on nm.startup_cost = hl2.text_startup::numeric
                      and nm.total_cost = hl2.text_total::numeric
),
tblname as (select distinct tblname.schname , tblname.objname, (tblname.schname || '.' || tblname.objname)::regclass::oid as oid from plan_table , lateral extract_info(jsonplan::jsonb,'Relation Name') as tblname),
idxname as (select distinct idxname.* from plan_table , lateral extract_info(jsonplan::jsonb,'Index Name') as idxname)
select string_agg(
	CASE
	WHEN col1 ~ '^rows=\d+\.\d+$'
	AND (select case when lnm.text_actual_rows is not null and lnm.text_plan_rows is not null
	     and greatest(lnm.text_actual_rows::numeric / greatest(lnm.text_plan_rows::numeric, 1),
	                  lnm.text_plan_rows::numeric / greatest(lnm.text_actual_rows::numeric, 1)) >= 2
	     then true else false end
	     from line_node_map lnm where lnm.line_num = plan_table1.r limit 1)
	THEN coalesce(
	  (select '<div class="tooltip-container"><span class="'
	    || case when greatest(lnm.text_actual_rows::numeric / greatest(lnm.text_plan_rows::numeric, 1),
	                          lnm.text_plan_rows::numeric / greatest(lnm.text_actual_rows::numeric, 1)) >= 20
	            then 'xplainattension' else 'xplaina' end
	    || '">' || plan_table1.col1
	    || '<div class="tooltip-content"><table class="tooltip-table">
	    <tr><th>Metric</th><th>Value</th></tr>
	    <tr><td>Node Type</td><td>' || coalesce(lnm.node_type, 'N/A') || '</td></tr>
	    <tr><td>Estimated Rows</td><td>' || coalesce(lnm.text_plan_rows, 'N/A') || '</td></tr>
	    <tr><td>Actual Rows</td><td>' || coalesce(lnm.text_actual_rows, 'N/A') || '</td></tr>
	    <tr><td>Estimate Error</td><td><span class="'
	      || case when greatest(lnm.text_actual_rows::numeric / greatest(lnm.text_plan_rows::numeric, 1),
	                            lnm.text_plan_rows::numeric / greatest(lnm.text_actual_rows::numeric, 1)) >= 20
	              then 'xplainattension' else 'xplaina' end
	      || '">'
	      || round(greatest(lnm.text_actual_rows::numeric / greatest(lnm.text_plan_rows::numeric, 1),
	                        lnm.text_plan_rows::numeric / greatest(lnm.text_actual_rows::numeric, 1)), 1)
	      || 'x '
	      || case when lnm.text_plan_rows::numeric > lnm.text_actual_rows::numeric
	              then 'overestimate' else 'underestimate' end
	      || '</span></td></tr>'
	    || case when lnm.relation_name is not null then coalesce(
	        (select '<tr><td>Root Cause</td><td>'
	          || case
	              when ts."MissingStats"
	                then '<span class="xplainattension">No statistics - planner used default estimate</span>'
	              when ts."LAnalyze" is null
	                then '<span class="xplainattension">Table never analyzed</span>'
	              when ts."Dtup" > ts."Ltup" * 0.1 and ts."Ltup" > 0
	                then '<span class="xplainattension">High dead rows (' || ts."Dtup" || ') - stats may be stale</span>'
	              else 'Consider running ANALYZE or creating extended statistics'
	            end
	          || '</td></tr>'
	          || '<tr><td>Last Analyze</td><td>' || coalesce(ts."LAnalyze", 'Never') || '</td></tr>'
	         from planstats.vw_table_stats ts
	         where ts."Sname" = lnm.schema_name and ts.relname = lnm.relation_name limit 1),
	        '') else '' end
	    || '</table></div></span></div>'
	  from line_node_map lnm where lnm.line_num = plan_table1.r limit 1),
	  plan_table1.col1)
	WHEN rows_removed_line AND col1 ~ '^\d+$'
	THEN coalesce((select '<div class="tooltip-container"><span class="xplaina">' || plan_table1.col1 || '<div class="tooltip-content"><table class="tooltip-table">
	<tr><th>Metric</th><th>Value</th></tr>
	<tr><td>Node Type</td><td>' || coalesce(lnm.node_type,'N/A') || '</td></tr>
	<tr><td>Table</td><td>' || coalesce(lnm.relation_name,'N/A') || '</td></tr>
	<tr><td>Plan Rows</td><td>' || coalesce(lnm.plan_rows,'N/A') || '</td></tr>
	<tr><td>Actual Rows</td><td>' || coalesce(lnm.actual_rows,'N/A') || '</td></tr>
	<tr><td>Rows Removed</td><td>' || plan_table1.col1 || '</td></tr>
	<tr><td>Filter Effectiveness</td><td>' || case when lnm.actual_rows is not null and plan_table1.col1 ~ '^\d+$' then round(plan_table1.col1::numeric / nullif(lnm.actual_rows::numeric + plan_table1.col1::numeric, 0) * 100, 1) || '%' else 'N/A' end || '</td></tr>
	<tr><td>Filter</td><td>' || coalesce(lnm.filter_expr, lnm.join_filter_expr, 'N/A') || '</td></tr>
	</table></div></span></div>'
	from line_node_map lnm where lnm.line_num = plan_table1.r limit 1), plan_table1.col1)
	WHEN heap_fetches_line AND col1 ~ '^\d+$'
	THEN coalesce((select '<div class="tooltip-container"><span class="xplaina">' || plan_table1.col1 || '<div class="tooltip-content"><table class="tooltip-table">
	<tr><th>Metric</th><th>Value</th></tr>
	<tr><td>Node Type</td><td>' || coalesce(lnm.node_type,'N/A') || '</td></tr>
	<tr><td>Table</td><td>' || coalesce(lnm.relation_name,'N/A') || '</td></tr>
	<tr><td>Actual Rows</td><td>' || coalesce(lnm.actual_rows,'N/A') || '</td></tr>
	<tr><td>Heap Fetches</td><td>' || plan_table1.col1 || '</td></tr>
	<tr><td>Heap Fetch Ratio</td><td>' || case when lnm.actual_rows is not null and lnm.actual_rows::numeric > 0 then round(plan_table1.col1::numeric / lnm.actual_rows::numeric, 2)::text else 'N/A' end || '</td></tr>
	<tr><td>Visibility</td><td>' || case when lnm.actual_rows is not null and plan_table1.col1::numeric > lnm.actual_rows::numeric then '<span class="xplainattension">High heap fetches - visibility map may need VACUUM</span>' else 'OK' end || '</td></tr>
	</table></div></span></div>'
	from line_node_map lnm where lnm.line_num = plan_table1.r limit 1), plan_table1.col1)
	WHEN sort_space_line AND col1 ~ '^\d+kB$'
	THEN coalesce((select '<div class="tooltip-container"><span class="' || case when lnm.sort_space_type = 'Disk' then 'xplainattension' else 'xplaina' end || '">' || plan_table1.col1 || '<div class="tooltip-content"><table class="tooltip-table">
	<tr><th>Metric</th><th>Value</th></tr>
	<tr><td>Node Type</td><td>' || coalesce(lnm.node_type,'N/A') || '</td></tr>
	<tr><td>Sort Key</td><td>' || coalesce(lnm.sort_key,'N/A') || '</td></tr>
	<tr><td>Space Used</td><td>' || plan_table1.col1 || '</td></tr>
	<tr><td>Space Type</td><td>' || coalesce(lnm.sort_space_type,'N/A') || '</td></tr>
	<tr><td>Warning</td><td>' || case when lnm.sort_space_type = 'Disk' then '<span class="xplainattension">Spilled to disk - consider increasing work_mem</span>' else 'Sort completed in memory' end || '</td></tr>
	</table></div></span></div>'
	from line_node_map lnm where lnm.line_num = plan_table1.r limit 1), plan_table1.col1)
	WHEN hash_batches_line AND col1 ~ '^\d+$'
	THEN coalesce((select '<div class="tooltip-container"><span class="' || case when lnm.original_hash_batches is not null and lnm.hash_batches is not null and lnm.hash_batches::int > lnm.original_hash_batches::int then 'xplainattension' else 'xplaina' end || '">' || plan_table1.col1 || '<div class="tooltip-content"><table class="tooltip-table">
	<tr><th>Metric</th><th>Value</th></tr>
	<tr><td>Node Type</td><td>' || coalesce(lnm.node_type,'N/A') || '</td></tr>
	<tr><td>Hash Buckets</td><td>' || coalesce(lnm.hash_buckets,'N/A') || '</td></tr>
	<tr><td>Planned Batches</td><td>' || coalesce(lnm.original_hash_batches,'N/A') || '</td></tr>
	<tr><td>Actual Batches</td><td>' || coalesce(lnm.hash_batches,'N/A') || '</td></tr>
	<tr><td>Warning</td><td>' || case when lnm.original_hash_batches is not null and lnm.hash_batches is not null and lnm.hash_batches::int > lnm.original_hash_batches::int then '<span class="xplainattension">Hash overflowed - batches increased from ' || lnm.original_hash_batches || ' to ' || lnm.hash_batches || '. Consider increasing work_mem</span>' else 'No overflow' end || '</td></tr>
	</table></div></span></div>'
	from line_node_map lnm where lnm.line_num = plan_table1.r limit 1), plan_table1.col1)
	WHEN buffers_line AND col1 ~ '^(hit|read)=\d+$'
	THEN coalesce((select '<div class="tooltip-container"><span class="xplaina">' || plan_table1.col1 || '<div class="tooltip-content"><table class="tooltip-table">
	<tr><th>Metric</th><th>Value</th></tr>
	<tr><td>Node Type</td><td>' || coalesce(lnm.node_type,'N/A') || '</td></tr>
	<tr><td>Shared Hit Blocks</td><td>' || coalesce(lnm.shared_hit_blocks,'0') || '</td></tr>
	<tr><td>Shared Read Blocks</td><td>' || coalesce(lnm.shared_read_blocks,'0') || '</td></tr>
	<tr><td>Cache Hit Ratio</td><td>' || case when (coalesce(lnm.shared_hit_blocks,'0')::numeric + coalesce(lnm.shared_read_blocks,'0')::numeric) > 0 then round(coalesce(lnm.shared_hit_blocks,'0')::numeric / (coalesce(lnm.shared_hit_blocks,'0')::numeric + coalesce(lnm.shared_read_blocks,'0')::numeric) * 100, 1) || '%' else 'N/A' end || '</td></tr>
	</table></div></span></div>'
	from line_node_map lnm where lnm.line_num = plan_table1.r limit 1), plan_table1.col1)
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
				    <th>BloatPCT%</th>
				    <th>HOT Rate</th>
				    <th>AV Status</th>
				  	<th>LVacuumTime</th>
				    <th>LAnalyzeTime</th>
                </tr>' ||
				  (select concat_ws('','<tr><td>',"SchemaName",'</td><td>',"TableName",'</td><td>',"Table_Size",'</td><td class="'|| case when "MissingStats" = 'Yes' then 'xplainattension' else '""' end || '">',"MissingStats",'</td><td>',"Index_Size",'</td><td>',"TablePages",'</td><td>',"LiveRows",'</td><td>',"DeadRows",
				 '</td><td class="' || case when "BloatPCT" > 20 then 'xplainattension' else '""' end || '">',"BloatPCT",'%</td><td>',"HOTRate",'%</td><td class="' || case when "AVStatus" = 'Due To Run' then 'xplainattension' else '""' end || '">',"AVStatus",'</td><td>',"LVacuumTime",'</td><td>',"LAnalyzeTime",'</td></tr>')
from
(select tbls."Sname" as "SchemaName",
tbls."relname" as "TableName", pg_size_pretty(pg_relation_size((tbls."Sname" || '.' || tbls."relname")::regclass)) as "Table_Size",
pg_size_pretty(pg_total_relation_size((tbls."Sname" || '.' || tbls."relname")::regclass) - pg_relation_size((tbls."Sname" || '.' || tbls."relname")::regclass)) as "Index_Size",
tbls."Pages"      as "TablePages",
tbls."Ltup"       as "LiveRows",
tbls."Dtup"       as "DeadRows",
tbls."LVacuum"    as "LVacuumTime",
tbls."LAnalyze"   as "LAnalyzeTime",
case when tbls."MissingStats" then 'Yes' else 'No' end as "MissingStats",
coalesce(tbls."BloatPCT%", 0) as "BloatPCT",
coalesce(tbls."hot_rate", 0) as "HOTRate",
coalesce(tbls."expect_av", '') as "AVStatus"
 from planstats.vw_table_stats tbls , tblname
 where tbls.oid = tblname.oid
and exists (SELECT 1 FROM tblname WHERE strpos(plan_table1.col1,(tbls."Sname" || '.' || tbls."relname")) > 0)) alias1)
				  ||'</table></div></a></div>'
WHEN exists (SELECT 1 FROM idxname WHERE strpos(plan_table1.col1,idxname.objname) > 0)
THEN '<div class="tooltip-container"><a class ="xplaina" href="#Databaseobjects3">' || plan_table1.col1 || '<div class="tooltip-content"><table class="tooltip-table">
				  <tr>
                    <th>SchemaName</th>
                    <th>TableName</th>
				    <th>IndexName</th>
                    <th>IndexSize</th>
                    <th>IndexScan</th>
				    <th>LastIndexScan</th>
				    <th>IndexEntryScan</th>
				    <th>TableRowsFetch</th>
				    <th>Selectivity</th>
				  	<th>IndexDefinition</th>
                </tr>' ||
				  (select concat_ws('','<tr><td>',"SchemaName",'</td><td>',"TableName",'</td><td>',"IndexName",'</td><td>',"IndexSize",'</td><td>',"IndexScan",'</td><td>',"LastIndexScan",'</td><td>',"IndexEntryScan",'</td><td>',"TableRowsFetch",
				 '</td><td>',"Selectivity",'</td><td>',"IndexDef",'</td></tr>')
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
case when idx."TRead" > 0 then round(idx."TFetch"::numeric / idx."TRead"::numeric, 3)::text else 'N/A' end as "Selectivity",
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
					<th>MCV (Top 5)</th>
					<th>MVF (Top 5)</th>
                </tr>' ||
				  (select concat_ws('','<tr><td>',"TableName",'</td><td>',"ColumnName",'</td><td>',"DataType",'</td><td>',"Nullable",'</td><td>',"Null Fraction",
									'</td><td>',"Distinct",'</td><td>',"Correlation",
				 '</td><td>',"Selectivity",'</td><td>',"Storage Type",'</td><td>',"Statistics Target",'</td><td>',"MCV",'</td><td>',"MVF",'</td></tr>')
from
(SELECT  cols."TName" as "TableName" , cols."CName" as "ColumnName" , cols."Type"       as "DataType",
cols."NULL?"      as "Nullable",
cols."Null%"      as "Null Fraction",
cols."Distnct"    as "Distinct",
cols."Cluster"    as "Correlation",
cols."Selectivity" as "Selectivity",
cols."Store"      as "Storage Type",
cols."StatTarget" as "Statistics Target",
coalesce(cols."MCV"::text, 'N/A') as "MCV",
coalesce(cols."MVF"::text, 'N/A') as "MVF"
 from planstats.VW_COLUMN_STATS cols , tblname
	where cols.oid = tblname.oid and  strpos(split_part(plan_table1.col1,'.',2),cols."CName") > 0 limit 1) alias1 limit 1)
				  ||'</table></div></a></div>',plan_table1.col1)
else plan_table1.col1
end,' ')
from plan_table1
GROUP BY r order by r ;
\qecho </pre>
\qecho </div>
\qecho </section>
\pset format unaligned
\pset tuples_only on
\qecho <section data-section="recommendations" id="Recommendations" class="anchor">
\qecho <h2>Expert Recommendations</h2>
\qecho <h4>Automated analysis of the execution plan with actionable tuning advice.</h4>
\qecho <nav class="section-nav"><a href="#QueryDetails">Previous</a> <a href="#report-header">Top</a> <a href="#Databaseobjects1">Next</a></nav>
\qecho <div class="recommendations-section">

SELECT COALESCE(
  (SELECT string_agg(
    concat_ws('',
      '<div class="rec-' || lower(r.severity) || '">',
      '<span class="rec-badge badge-' || lower(r.severity) || '">' || r.severity || '</span>',
      '<span class="rec-badge" style="background-color:#607d8b">' || r.category || '</span>',
      '<div class="rec-title">' || r.finding || '</div>',
      '<div class="rec-action">Recommendation: ' || r.recommendation || '</div>',
      CASE WHEN r.details IS NOT NULL AND r.details != ''
           THEN '<div class="rec-detail">Details: ' || r.details || '</div>'
           ELSE '' END,
      '</div>'), ''
    ORDER BY
      CASE r.severity WHEN 'HIGH' THEN 1 WHEN 'MEDIUM' THEN 2 ELSE 3 END,
      r.category)
   FROM planstats.generate_recommendations(:planid) r),
  '<div class="rec-none">No recommendations found. The execution plan looks efficient.</div>'
);

\qecho </div>
\qecho </section>
\pset format html
\pset tuples_only off
\echo Gathering Database Object Stats for Query ID(:queryid)
\qecho <section data-section="performance-stats" id="Databaseobjects" class="anchor">
\qecho <h2>Query and Object Statistics</h2>
\qecho <h4>This section shows underlying statistics of objects involved in the execution plan of the SQL.</h4>
\qecho <div id="Databaseobjects1" class="anchor"></div>
\if :has_pgss
\qecho <h2>Performance Metrics - pg_stat_statements</h2>
\qecho <nav class="section-nav"><a href="#Recommendations">Previous</a> <a href="#report-header">Top</a> <a href="#Databaseobjects2">Next</a></nav>
\qecho <h4>This section shows the underlying runtime execution stats of SQL.</h4>

\if :pg17plus
SELECT        queryid as "QueryID",
              round(mean_plan_time::numeric, 2) as  "Mean_Planning_Time",
              round(mean_exec_time::numeric, 2) AS  "Mean_Execution_Time",
              round(stddev_exec_time::numeric, 2) AS  "Standard_Deviation_Exec_Time",
              rows/nullif(calls,0) as "Row_Per_Exec" ,
              calls as "Calls",
              plans as "Plan Count",
              (shared_blk_read_time+shared_blk_write_time+local_blk_read_time+local_blk_write_time)/nullif(calls,0) as "Disk IO per Call",
              (shared_blks_hit+shared_blks_dirtied)/nullif(calls,0) as "Buffer IO per Call",
              temp_blks_written as "Disk Temp Usage"
FROM    pg_stat_statements
where queryid = :'queryid'
ORDER BY total_exec_time DESC;
\else
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
\endif
\else
\qecho <h2>Performance Metrics - pg_stat_statements</h2>
\qecho <h4>pg_stat_statements extension is not installed or active. Skipping query performance stats.</h4>
\endif
\qecho </section>

\qecho <section data-section="table-stats" id="Databaseobjects2" class="anchor">
\qecho <h2>Database Table Stats Summary</h2>
\qecho <nav class="section-nav"><a href="#Databaseobjects1">Previous</a> <a href="#report-header">Top</a> <a href="#Databaseobjects3">Next</a></nav>
\qecho <h4>This section shows the underlying stats of the table referenced in the execution plan.</h4>

with plan_table as (select * from plan_table where planid = :planid),
tblname as (select distinct (tblname.schname || '.' || tblname.objname)::regclass::oid as oid from plan_table , lateral extract_info(jsonplan::jsonb,'Relation Name') as tblname)
select distinct tbls."Sname"      as "SchemaName",
tbls.relname    as "TableName",
pg_size_pretty(pg_relation_size((tbls."Sname" || '.' || tbls.relname)::regclass)) as "Table_Size",
pg_size_pretty(pg_total_relation_size((tbls."Sname" || '.' || tbls.relname)::regclass) - pg_relation_size((tbls."Sname" || '.' || tbls.relname)::regclass)) as "Index_Size",
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
\qecho </section>

\qecho <section data-section="index-stats" id="Databaseobjects3" class="anchor">
\qecho <h2>Database Index Stats Summary</h2>
\qecho <nav class="section-nav"><a href="#Databaseobjects2">Previous</a> <a href="#report-header">Top</a> <a href="#Databaseobjects4">Next</a></nav>
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
\qecho </section>

\qecho <section data-section="column-stats" id="Databaseobjects4" class="anchor">
\qecho <h2>Execution Plan Columns Stats Summary</h2>
\qecho <nav class="section-nav"><a href="#Databaseobjects3">Previous</a> <a href="#report-header">Top</a> <a href="#Databaseobjects5">Next</a></nav>
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
\qecho </section>

\qecho <section data-section="extended-stats" id="Databaseobjects5" class="anchor">
\qecho <h2>Execution Plan Extended Stats Summary</h2>
\qecho <nav class="section-nav"><a href="#Databaseobjects4">Previous</a> <a href="#report-header">Top</a> <a href="#Databaseobjects6">Next</a></nav>
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
\qecho </section>

\qecho <section data-section="trigger-stats" id="Databaseobjects6" class="anchor">
\qecho <h2>Execution Plan Trigger Stats Summary</h2>
\qecho <nav class="section-nav"><a href="#Databaseobjects5">Previous</a> <a href="#report-header">Top</a> <a href="#Databaseobjects7">Next</a></nav>
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
\qecho </section>

\qecho <section data-section="function-stats" id="Databaseobjects7" class="anchor">
\qecho <h2>Execution Plan Function Stats Summary</h2>
\qecho <nav class="section-nav"><a href="#Databaseobjects6">Previous</a> <a href="#report-header">Top</a> <a href="#DatabaseConfDetails">Next</a></nav>
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
\qecho </section>

\qecho <section data-section="db-details" id="DatabaseConfDetails" class="anchor">
\qecho <h2>Additional Configuration and Database Details</h2>
\qecho <h4>This section shows additional database details along with must-know configurations for execution plan analysis.</h4>
\qecho <nav class="section-nav"><a href="#Databaseobjects7">Previous</a> <a href="#report-header">Top</a> <a href="#DatabaseConfDetails2">Next</a></nav>
\qecho <div id="DatabaseConfDetails1" class="anchor"></div>
\qecho <h2>PostgreSQL Version and Database Details</h2>
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
\qecho </section>

\qecho <section data-section="execution-settings" id="DatabaseConfDetails2" class="anchor">
\qecho <h2>Database Settings During Execution</h2>
\qecho <nav class="section-nav"><a href="#DatabaseConfDetails1">Previous</a> <a href="#report-header">Top</a> <a href="#DatabaseConfDetails3">Next</a></nav>
\pset footer off

select s.key as "Execution Plan Setting", s.value as "Value"
from planstats.plan_table  , lateral jsonb_each_text(CASE WHEN jsonplan::jsonb->0 ? 'Settings' THEN jsonplan::jsonb->0 -> 'Settings' END) as s
where planid = :planid order by 1 ;
\qecho </section>

\qecho <section data-section="non-default-settings" id="DatabaseConfDetails3" class="anchor">
\qecho <h2>Database Parameter Settings Other Than Defaults</h2>
\qecho <nav class="section-nav"><a href="#DatabaseConfDetails2">Previous</a> <a href="#report-header">Top</a> <a href="#DatabaseConfDetails4">Next</a></nav>

SELECT s.name AS "Parameter", pg_catalog.current_setting(s.name) AS "Value"
FROM pg_catalog.pg_settings s
WHERE s.source <> 'default' AND
      s.setting IS DISTINCT FROM s.boot_val
      and (s.name not like '%file%' and s.name not like '%directory%')
ORDER BY 1;
\qecho </section>

\qecho <section data-section="plan-config-settings" id="DatabaseConfDetails4" class="anchor">
\qecho <h2>Important Configuration Settings for Execution Plan</h2>
\qecho <nav class="section-nav"><a href="#DatabaseConfDetails3">Previous</a> <a href="#report-header">Top</a></nav>

SELECT s.name AS "Parameter", pg_catalog.current_setting(s.name) AS "Value"
FROM pg_catalog.pg_settings s
WHERE pg_catalog.lower(s.name) OPERATOR(pg_catalog.~) '^(work_mem|random_page_cost|seq_page_cost|default_statistics_target|hash_mem_multiplier|temp_buffers|plan_cache_mode|from_collapse_limit|join_collapse_limit|max_parallel_workers|max_parallel_workers_per_gather|min_parallel_table_scan_size)$' COLLATE pg_catalog.default
ORDER BY 1;
\qecho </section>

\qecho <footer>
\qecho  Created by DataCloudGaze Consulting<br>
\qecho   <a href="mailto:contact@datacloudgaze.com">Report Issue - contact@datacloudgaze.com</a><br>
\qecho   <a href="https://www.datacloudgaze.com/">About Us</a>
\qecho </footer>
\qecho </main>
\qecho </body>
\qecho </html>
\echo Underlying Statistics curated for Query(:queryid) - Output File :htmlfile

