drop table if exists testplanstats;

create table testplanstats as 
	select generate_series col1, 
	case when mod(generate_series,99) between 0 and 50 then null else mod(generate_series,9999)+1 end col2,  
	mod(generate_series,99) col3 from generate_series(1,100000);

alter table testplanstats add unique(col1);
create index idx_testplanstats1 on testplanstats(col2);
ALTER TABLE testplanstats ALTER COLUMN col2 SET STATISTICS 300; 

create statistics teststats1(dependencies,ndistinct,mcv) on col2, col3
from testplanstats;

vacuum analyze testplanstats;

SELECT PLANSTATS.RUN_PLAN_ANALYZE
	($$select *
		FROM testplanstats
		WHERE col1 = 1
		UNION ALL SELECT *
		FROM testplanstats
		WHERE col2 = 1
		UNION ALL SELECT *
		FROM testplanstats
		WHERE col3 = 1 $$);

--Running base statsviaexplainanalyze report
PGPASSWORD=******* psql -h localhost -U postgres -d plantest -q -v ON_ERROR_STOP=1 -f stats_via_explain_analyze.sql

--Running Dalibo Integrated statsviaexplainanalyse report.
PGPASSWORD=******* psql -h localhost -U postgres -d plantest -q -v ON_ERROR_STOP=1 -f explain_dalibo.sql -f stats_via_explain_analyze_with_dalibo.sql

--Running base statsviaexplainanalyze report using query_id filter
PGPASSWORD=******* psql -h localhost -U postgres -d plantest -q -v ON_ERROR_STOP=1 -v query_id=7740365855379636009 -f stats_via_explain_analyze.sql

--Running Dalibo Integrated statsviaexplainanalyse report using query_id filter
PGPASSWORD=******* psql -h localhost -U postgres -d plantest -q -v ON_ERROR_STOP=1 -v query_id=7740365855379636009 -f explain_dalibo.sql -f stats_via_explain_analyze_with_dalibo.sql

SELECT PLANSTATS.RUN_PLAN_EXPLAIN
	($$select *
		FROM testplanstats
		WHERE col1 = 2
		UNION ALL SELECT *
		FROM testplanstats
		WHERE col2 = 2
		UNION ALL SELECT *
		FROM testplanstats
		WHERE col3 = 2 $$);

--Running base statsviaexplainanalyze report
PGPASSWORD=******* psql -h localhost -U postgres -d plantest -q -v ON_ERROR_STOP=1 -f stats_via_explain_analyze.sql



