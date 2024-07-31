# statsviaexplainanalyze

Analyzing execution plans is made easier with curating statistics of database objects such as tables, indexes, or columns involved in the execution plan, all within a single report. This makes it easier to share among team members and reduces the need for additional information requests.

This tool automates the curation of object statistics when analyzing problematic execution plans in PostgreSQL using an HTML template and the `psql` command line.

## How it Works?
Problematic SQL is run within `EXPLAIN ANALYZE BUFFERS` within wrapper function code, and the underlying execution plan, both in JSON (`EXPLAIN` only) and Text (`EXPLAIN ANALYZE BUFFERS`), is stored in the plan_table.

Using the `psql` command line, the current statistics of all database objects are fetched and included in the HTML output. The HTML output can also be integrated with the [PEV2 visualiser](https://github.com/dalibo/pev2).

<div align="center">
  <img src="https://github.com/user-attachments/assets/54bd8058-ed83-495b-95b5-ed3836f0935e" alt="Screen Recording" width="550" height="250"/>
</div>

## Installation 

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

## Generating Execution Plan and Underlying stats on objects.
We have multiple options to generate report either directly from pg_stat_statements using GENERIC_PLAN supported since PostgreSQL or run SQL within wrapper functions from planstats schema.

### Option 1 - Running Problematic SQL using Wrapper

Using Dollar Quoting enclosed problematic SQL as input.

```
plantest=# select planstats.run_plan_analyze($$select count(1) from emp$$);
    run_plan_analyze
-------------------------
 (1,7335632667878063635)
(1 row)
```

Generating statsviaexplainanalyze report using `psql` command line.By default it will generate report for last plan analyzed.

```
PGPASSWORD=********* psql -h <<PostgresHost>> -U <<PGuser>> -d <<Databases>>  -q -v ON_ERROR_STOP=1 -f stats_via_explain_analyze.sql
Gathering Database Object Stats for Query ID(7335632667878063635)
Underlying Statistics curated for Query(7335632667878063635) - Output File Stats_Via_Explain_Analyze_7335632667878063635.html
```

### Option 2 - Running Only Explain on Problematic SQL using Wrapper

Using Dollar Quoting enclosed problematic SQL as input.

```
plantest=# select planstats.run_plan_explain($$select count(1) from emp$$);
    run_plan_analyze
-------------------------
 (1,7335632667878063635)
(1 row)
```

Generating statsviaexplainanalyze report using `psql` command line. By default it will generate report for last plan explained.

```
PGPASSWORD=********* psql -h <<PostgresHost>> -U <<PGuser>> -d <<Databases>>  -q -v ON_ERROR_STOP=1 -f stats_via_explain_analyze.sql
Gathering Database Object Stats for Query ID(7335632667878063635)
Underlying Statistics curated for Query(7335632667878063635) - Output File Stats_Via_Explain_Analyze_7335632667878063635.html
```

### Option 3 - Running using `pg_stat_statements`
Using -v option of `psql`, we can pass `queryid` filters along with `pg_stat_statements` to use internal performance views to extract query metadata.

```
PGPASSWORD=********* psql -h <<PostgresHost>> -U <<PGuser>> -d <<Databases>>  -q -v ON_ERROR_STOP=1 -v query_id=8192079375982646892 -v pg_stat_statements= -f stats_via_explain_analyze.sql
```

## Integrations with `Pev2 Visualiser`
Integrate Execution plan objects statistics with [PEV2 visualiser](https://github.com/dalibo/pev2) a graphical vizualization of a PostgreSQL execution plan.

With any of the options we choose to get underlying stats of Objects, we can combine with Pev2.

```
PGPASSWORD=********* psql -h <<PostgresHost>> -U <<PGuser>> -d <<Databases>>  -q -v ON_ERROR_STOP=1 -f explain_dalibo.sql -f stats_via_explain_analyze_with_dalibo.sql
```

It used two html files and combined it together using iframe.

