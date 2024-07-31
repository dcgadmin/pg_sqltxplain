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

List of Objects include


## Generating Execution Plan and Underlying stats on objects.

## Integrations with `Pev2 Visualiser`

