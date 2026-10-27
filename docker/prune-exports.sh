#!/bin/bash
# Trims the endTB exports (bahmni-batch), keeping for each job the last export of each month, for the newest
# 19 months: the zips in /home/bahmni/endtb_export, and the job's run history in the database, which the
# Exports page (report.html) lists. Runs before each export (see the crontab): with the run it adds, each job
# has at most 20, all the page shows, so the page lists exactly the zips there are.
# Runs whose zip isn't kept (or that wrote none: failed, or stopped part way) go from the history too, apart
# from one still running.
# Usage: prune-exports [dir]   (default /home/bahmni/endtb_export)
set -u
MONTHS=19
dir=${1:-/home/bahmni/endtb_export}
cd "$dir" 2>/dev/null || exit 0

# The zips: <job name><yyyyMMddHHmm>.zip. Per job, the newest of each month, for the newest $MONTHS months.
keep=$(ls -1 | grep -E '[0-9]{12}\.zip$' | sort -r | awk -v months=$MONTHS '{
  ts = substr($0, length($0) - 15, 12); job = substr($0, 1, length($0) - 16); month = substr(ts, 1, 6)
  if ((job, month) in seen) next
  seen[job, month] = 1
  if (++count[job] <= months) print
}')
ls -1 | grep -E '[0-9]{12}\.zip$' | while IFS= read -r f; do
  grep -qxF -- "$f" <<< "$keep" || { rm -f -- "$f" && echo "Deleted export $f"; }
done

# The run history: every run apart from those of the kept zips, and one started in the last 12 hours
. /etc/bahmni-installer/bahmni.conf
keep_sql=$(sed "s/'/''/g; s/.*/('&')/" <<< "$keep" | paste -sd, -)
MYSQL_PWD=$OPENMRS_DB_PASSWORD mysql -h "$OPENMRS_DB_SERVER" -u "$OPENMRS_DB_USERNAME" openmrs <<SQL
CREATE TEMPORARY TABLE keep_zip (name VARCHAR(255) PRIMARY KEY);
${keep_sql:+INSERT INTO keep_zip VALUES $keep_sql;}
CREATE TEMPORARY TABLE old_execution (id BIGINT PRIMARY KEY)
  SELECT e.JOB_EXECUTION_ID AS id
  FROM BATCH_JOB_EXECUTION e LEFT JOIN BATCH_JOB_EXECUTION_CONTEXT c ON c.JOB_EXECUTION_ID = e.JOB_EXECUTION_ID
  WHERE NOT (e.STATUS = 'STARTED' AND e.CREATE_TIME > NOW() - INTERVAL 12 HOUR)
    AND NOT (e.STATUS = 'COMPLETED' AND SUBSTRING_INDEX(SUBSTRING_INDEX(c.SHORT_CONTEXT, '"outputFileName","', -1), '"', 1)
             IN (SELECT name FROM keep_zip));
DELETE sc FROM BATCH_STEP_EXECUTION_CONTEXT sc
  JOIN BATCH_STEP_EXECUTION s ON s.STEP_EXECUTION_ID = sc.STEP_EXECUTION_ID JOIN old_execution o ON o.id = s.JOB_EXECUTION_ID;
DELETE s FROM BATCH_STEP_EXECUTION s JOIN old_execution o ON o.id = s.JOB_EXECUTION_ID;
DELETE c FROM BATCH_JOB_EXECUTION_CONTEXT c JOIN old_execution o ON o.id = c.JOB_EXECUTION_ID;
DELETE p FROM BATCH_JOB_EXECUTION_PARAMS p JOIN old_execution o ON o.id = p.JOB_EXECUTION_ID;
DELETE e FROM BATCH_JOB_EXECUTION e JOIN old_execution o ON o.id = e.JOB_EXECUTION_ID;
DELETE i FROM BATCH_JOB_INSTANCE i LEFT JOIN BATCH_JOB_EXECUTION e ON e.JOB_INSTANCE_ID = i.JOB_INSTANCE_ID
  WHERE e.JOB_EXECUTION_ID IS NULL;
SELECT CONCAT('Export runs kept in the history: ', COUNT(*)) FROM BATCH_JOB_EXECUTION;
SQL
