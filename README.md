# statsviaexplainanalyze - Simplifying PostgreSQL Execution Plan Analysis.

Analyzing execution plans is made easier with curating execution plan, statistics of database objects such as tables, indexes, or columns involved in the actual runtime execution plan, all within a single report. This makes it easier to share among team members or external forum and reduces the need for additional information requests.

This tool automates the curation of object statistics when analyzing problematic execution plans in PostgreSQL using an HTML template embded in sql file and the `psql` command line.

## How it Works?
Execution plan is generated either by `Explain Analyze Buffers` or only with `Explain` and stored in a plantable.

Using the `psql` command line, the current statistics of all database objects involved in Execution plan are fetched and included in the HTML output. The output can also be integrated with the [PEV2 visualiser](https://github.com/dalibo/pev2).

<div align="center">
  <img src="https://github.com/user-attachments/assets/6ab56914-2158-44eb-b663-062b861e153b" alt="Screen Recording" width="600" height="450"/>
</div>

## Installation 
Setup Databases with necessary wrappers code that generate execution plan and stored it in plantable.

### Extension Dependency 
This tool uses the `pg_stat_statements` view to extract runtime information of problematic SQL using `queryid`. It can also be used as filters to gather Generic Plan from `pg_stat_statements`. The `pgstattuple` extension is used to extract bloat-related information, though it is optional.

```
        Name        |                              Description
--------------------+------------------------------------------------------------------------
 pg_stat_statements | track planning and execution statistics of all SQL statements executed
 pgstattuple        | show tuple-level statistics

```

### Creating planstats schema
Gathering statistics requires traversing all execution plan steps and extracting the objects involved. We have built all necessary wrappers with functions and views within the `planstats` schema. You need to set it up on the concerned databases.

```
PGPASSWORD=******** psql -h <<PostgresHost>> -U <<SuperUser>> -d <<Databases>> -f statsviaexplainanalyze/statsviaexplainanalyze_setup.sql
```

## Generating Report including underlying stats on objects and execution plan.
We have multiple options to generate report either directly from pg_stat_statements using GENERIC_PLAN supported since PostgreSQL 16 or run SQL within wrapper functions `(run_plan_analyze/run_plan_explain)`

### Option 1 - Running Problematic SQL using `run_plan_analyze` Wrapper

Using Dollar Quoting enclosed problematic SQL as input and run it using function `run_plan_analyze` defined in `planstats` schema.

```
plantest=# select planstats.run_plan_analyze($$select count(1) from emp$$);
    run_plan_analyze
-------------------------
 (1,7335632667878063635)
(1 row)
```
It will return internal planid and queryid for further references.

In next steps, we will generate statsviaexplainanalyze report using `psql` command line.If no Filter is provided by default it will generate report on last plan analyzed(max-planid).

```
PGPASSWORD=********* psql -h <<PostgresHost>> -U <<PGuser>> -d <<Databases>>  -q -v ON_ERROR_STOP=1 -v query_id=7335632667878063635 -f stats_via_explain_analyze.sql
Gathering Database Object Stats for Query ID(7335632667878063635)
Underlying Statistics curated for Query(7335632667878063635) - Output File Stats_Via_Explain_Analyze_7335632667878063635.html
```

Please note - Replace Host, DBname and Password as per your DB instances.

### Option 2 - Running Only Explain on Problematic SQL using Wrapper

Using Dollar Quoting enclosed problematic SQL as input and run it using function `run_plan_explain` defined in `planstats` schema.

```
plantest=# select planstats.run_plan_explain($$select count(1) from emp$$);
    run_plan_analyze
-------------------------
 (1,7335632667878063635)
(1 row)
```

In next steps, we will generate statsviaexplainanalyze report using `psql` command line.If no Filter is provided by default it will generate report on last plan analyzed(max-planid).

```
PGPASSWORD=********* psql -h <<PostgresHost>> -U <<PGuser>> -d <<Databases>>  -q -v ON_ERROR_STOP=1 -v query_id=7335632667878063635 -f stats_via_explain_analyze.sql
Gathering Database Object Stats for Query ID(7335632667878063635)
Underlying Statistics curated for Query(7335632667878063635) - Output File Stats_Via_Explain_Analyze_7335632667878063635.html
```

### Option 3 - Running using `pg_stat_statements` performance views (Preferably for PostgreSQL 16 onwards)
Using -v option of `psql`, we can pass `queryid` filters along with `pg_stat_statements` to use internal performance views to extract query metadata. It internally used `GENERIC_PLAN` plan options to generate underlying explain plan using `query` column.

```
PGPASSWORD=********* psql -h <<PostgresHost>> -U <<PGuser>> -d <<Databases>>  -q -v ON_ERROR_STOP=1 -v query_id=8192079375982646892 -v pg_stat_statements= -f stats_via_explain_analyze.sql
```

## Integrations with `Pev2 Visualiser`
Integrate Execution plan objects statistics with [PEV2 visualiser](https://github.com/dalibo/pev2) a graphical vizualization of a PostgreSQL execution plan.

With any of the options mentioned previously, we can choose to get underlying stats of Objects and integrate it with PEV2. 
Internally it use two sql file to generate couple of html report as we are using iframe html tag to take care of different stylesheet.

```
PGPASSWORD=********* psql -h <<PostgresHost>> -U <<PGuser>> -d <<Databases>>  -q -v ON_ERROR_STOP=1 -f explain_dalibo.sql -f stats_via_explain_analyze_with_dalibo.sql
```



