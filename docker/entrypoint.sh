#!/bin/bash
# Starts the Kazakhstan EMR (Bahmni 0.89): sets the database and service credentials from env, makes
# sure /openmrs/data has what it needs, runs the reports' migrations, then starts OpenMRS, Bahmni
# reports, once OpenMRS is up Apache on 8080, and cron. The services' log files go to the container's
# log as they're written. Exits if OpenMRS or the reports stop.
#
# Env (the openmrs service passes the instance's OMRS_* lines):
#   OMRS_CONFIG_CONNECTION_SERVER/_DATABASE/_USERNAME/_PASSWORD  the openmrs database (set by openmrs.yaml)
#   OMRS_REPORTS_DB_PASSWORD       the reports' own database (bahmni_reports), user OMRS_REPORTS_DB_USER
#                                  (default reports-user): an OPENMRS_DB_ACCOUNT_* account of the instance
#   OMRS_REPORTS_OPENMRS_PASSWORD  the OpenMRS user the reports log in as, OMRS_REPORTS_OPENMRS_USER
#                                  (default reports-user)
#   OMRS_JAVA_MEMORY_OPTS          OpenMRS's JVM memory options (optional)
#   OMRS_BATCH_EXPORTS             false: don't run the nightly endTB exports (bahmni-batch, scheduled as on
#                                  the server: /var/spool/cron/bahmni); default true
#   OMRS_APACHE_ACCESS_LOG         true: Apache's access log in the container's log; default false
#   TZ                             time zone
set -u
# UTF-8, as on the server (the reports' migrations run from here)
export LANG=en_US.UTF-8

need() { [ -n "${!1:-}" ] || { echo "ERROR: $1 is not set" >&2; exit 1; }; }
for v in OMRS_CONFIG_CONNECTION_SERVER OMRS_CONFIG_CONNECTION_DATABASE OMRS_CONFIG_CONNECTION_USERNAME \
         OMRS_CONFIG_CONNECTION_PASSWORD OMRS_REPORTS_DB_PASSWORD OMRS_REPORTS_OPENMRS_PASSWORD; do
  need "$v"
done
case "${OMRS_BATCH_EXPORTS:-true}" in
  true|false) ;;
  *) echo "ERROR: OMRS_BATCH_EXPORTS must be true or false" >&2; exit 1 ;;
esac
case "${OMRS_APACHE_ACCESS_LOG:-false}" in
  true|false) ;;
  *) echo "ERROR: OMRS_APACHE_ACCESS_LOG must be true or false" >&2; exit 1 ;;
esac
# The batch exports (their jar's own config) and prune-exports name the database openmrs
if [ "$OMRS_CONFIG_CONNECTION_DATABASE" != openmrs ]; then
  echo "ERROR: OMRS_CONFIG_CONNECTION_DATABASE must be openmrs" >&2; exit 1
fi
# docker stop: Apache and cron stopped, and the Java services sent SIGTERM (their init scripts' stop is kill -9;
# Bahmni's launcher has no shutdown hook, so they exit at once), within Docker's 10 seconds
running() { for p in "$@"; do kill -0 "$p" 2>/dev/null && return 0; done; return 1; }
stop() {
  echo "Stopping"
  service crond stop >/dev/null 2>&1
  pkill htcacheclean
  service httpd stop >/dev/null 2>&1
  pids=$(cat /opt/openmrs/run/openmrs.pid /opt/bahmni-reports/run/bahmni-reports.pid 2>/dev/null)
  if [ -n "$pids" ]; then
    kill $pids 2>/dev/null
    for i in $(seq 1 16); do running $pids || break; sleep 0.5; done
  fi
  exit 0
}
trap stop TERM INT

export DB_HOST=$OMRS_CONFIG_CONNECTION_SERVER DB_NAME=$OMRS_CONFIG_CONNECTION_DATABASE
export DB_USER=$OMRS_CONFIG_CONNECTION_USERNAME DB_PASSWORD=$OMRS_CONFIG_CONNECTION_PASSWORD
export REPORTS_DB_USER=${OMRS_REPORTS_DB_USER:-reports-user} REPORTS_DB_PASSWORD=$OMRS_REPORTS_DB_PASSWORD
export REPORTS_OPENMRS_USER=${OMRS_REPORTS_OPENMRS_USER:-reports-user}
export REPORTS_OPENMRS_PASSWORD=$OMRS_REPORTS_OPENMRS_PASSWORD

# --- Credentials and settings into the config files (values via env, so perl needs no escaping)
setline() { # <file> <key> <value>: replaces a key=value line's value with <value> as it is
  K=$2 V=$3 perl -i -pe 's/^(\s*(?:export\s+)?\Q$ENV{K}\E\s*=).*/$1$ENV{V}/' "$1"
  grep -qE "^\s*(export\s+)?$(printf '%s' "$2" | sed 's/\./\\./g')\s*=" "$1" || { echo "ERROR: no $2 in $1" >&2; exit 1; }
}
setprop() { # <file> <key> <value>: a Java properties line, where \ is an escape
  setline "$1" "$2" "${3//\\/\\\\}"
}
setsh() { # <file> <var> <value>: a shell-sourced VAR=value line, quoted for the shell
  setline "$1" "$2" "$(printf '%q' "$3")"
}
jdbc() { echo "jdbc:mysql://$DB_HOST:3306/$1"; }

p=/opt/openmrs/etc/openmrs-runtime.properties
setprop $p connection.url "$(jdbc "$DB_NAME")?autoReconnect=true&sessionVariables=storage_engine=InnoDB&useUnicode=true&characterEncoding=UTF-8&zeroDateTimeBehavior=convertToNull"
setprop $p connection.username "$DB_USER"
setprop $p connection.password "$DB_PASSWORD"

p=/opt/bahmni-reports/etc/bahmni-reports.properties
setprop $p openmrs.url "$(jdbc "$DB_NAME")?allowMultiQueries=true"
setprop $p openmrs.username "$DB_USER"
setprop $p openmrs.password "$DB_PASSWORD"
setprop $p bahmnireports.db.url "$(jdbc bahmni_reports)?allowMultiQueries=true"
setprop $p reports.username "$REPORTS_DB_USER"
setprop $p reports.password "$REPORTS_DB_PASSWORD"
setprop $p openmrs.service.user "$REPORTS_OPENMRS_USER"
setprop $p openmrs.service.password "$REPORTS_OPENMRS_PASSWORD"
# The reports read reports.json through Apache, which is plain HTTP on 8080 here
setprop $p reports.config.url "http://localhost:8080/bahmni_config/openmrs/apps/reports/reports.json"

for p in /etc/bahmni-installer/bahmni.conf /opt/openmrs/etc/bahmni-emr.conf /opt/bahmni-web/etc/bahmni-web.conf; do
  setsh $p OPENMRS_DB_SERVER "$DB_HOST"
  setsh $p OPENMRS_DB_USERNAME "$DB_USER"
  setsh $p OPENMRS_DB_PASSWORD "$DB_PASSWORD"
done
setsh /etc/bahmni-installer/bahmni.conf REPORTS_DB_SERVER "$DB_HOST"
setsh /etc/bahmni-installer/bahmni.conf REPORTS_DB_USERNAME "$REPORTS_DB_USER"
setsh /etc/bahmni-installer/bahmni.conf REPORTS_DB_PASSWORD "$REPORTS_DB_PASSWORD"

if [ -n "${OMRS_JAVA_MEMORY_OPTS:-}" ]; then
  setsh /opt/openmrs/etc/openmrs.conf SERVER_OPTS "$OMRS_JAVA_MEMORY_OPTS"
fi

if [ -n "${TZ:-}" ]; then
  [ -f "/usr/share/zoneinfo/$TZ" ] || { echo "ERROR: unknown time zone $TZ" >&2; exit 1; }
  ln -sfn "/usr/share/zoneinfo/$TZ" /etc/localtime
fi

# --- /openmrs/data: OpenMRS's application data directory (search index, complex obs, caches), with
# /home/bahmni (documents, images, uploads, report outputs) in bahmni/
mkdir -p /openmrs/data/bahmni /openmrs/data/lucene
# Bahmni's Groovy extensions, which it reads from the application data directory, are the site's config
for d in obscalculator ordertemplates encounterModifier patientMatchingAlgorithm elisFeedInterceptor; do
  [ -L /openmrs/data/$d ] || rm -rf /openmrs/data/$d
  ln -sfn /var/www/bahmni_config/openmrs/$d /openmrs/data/$d
done
[ -L /openmrs/data/bahmni_config ] || rm -rf /openmrs/data/bahmni_config
ln -sfn /var/www/bahmni_config /openmrs/data/bahmni_config
# Bahmni core's settings, which it also reads from there
ln -sfn /opt/openmrs/bahmnicore.properties /openmrs/data/bahmnicore.properties
# What the packages set up, where missing (a new volume, or one restored from the server's /home/bahmni)
cp -an /opt/home-bahmni-skel/. /openmrs/data/bahmni/
# The links to the image's config, also over a restored server's copies (which hold its credentials)
ln -sfn /opt/openmrs/etc/openmrs-runtime.properties /home/bahmni/.OpenMRS/openmrs-runtime.properties
ln -sfn /opt/openmrs/bahmnicore.properties /home/bahmni/.OpenMRS/bahmnicore.properties
ln -sfn /opt/openmrs/modules /home/bahmni/.OpenMRS/modules
ln -sfn /opt/bahmni-reports/etc/bahmni-reports.properties /home/bahmni/.bahmni-reports/bahmni-reports.properties
# Apache serves documents, images and uploads from here
chmod 755 /openmrs/data /openmrs/data/bahmni
# Everything to bahmni once (a new volume, or a restored one: initialize gives its files to root, this marker
# included), then only what the lines above make, not years of documents on every start
marker=/openmrs/data/.ownership-set
if [ "$(stat -c %U $marker 2>/dev/null)" != bahmni ]; then
  echo "Giving /openmrs/data to bahmni"
  find /openmrs/data ! -user bahmni -exec chown -h bahmni:bahmni {} +
  touch $marker && chown bahmni:bahmni $marker
else
  find /openmrs/data -maxdepth 1 ! -user bahmni -exec chown -h bahmni:bahmni {} +
  find /openmrs/data/bahmni -maxdepth 2 ! -user bahmni -exec chown -h bahmni:bahmni {} +
fi

# --- The database
export MYSQL_PWD=$DB_PASSWORD
until mysqladmin -h "$DB_HOST" -u "$DB_USER" ping >/dev/null 2>&1; do sleep 2; done
# The server answers ping before it accepts logins (and whatever the credentials)
for i in $(seq 1 30); do
  err=$(mysql -h "$DB_HOST" -u "$DB_USER" "$DB_NAME" -e 'select 1' 2>&1 >/dev/null) && break
  [ "$i" -eq 30 ] && { echo "ERROR: can't log in to $DB_NAME as $DB_USER: $err" >&2; exit 1; }
  sleep 2
done
tables=$(mysql -h "$DB_HOST" -u "$DB_USER" -N -e "select count(*) from information_schema.tables where table_schema='$DB_NAME'")
if [ "${tables:-0}" -eq 0 ]; then
  echo "ERROR: the $DB_NAME database is empty: load the server's dump into it (see README.md)" >&2
  exit 1
fi
# A new or restored index volume: OpenMRS rebuilds the index at start only when search.indexVersion
# doesn't match, and a restored dump has the server's value
if [ -z "$(ls -A /openmrs/data/lucene)" ]; then
  echo "Search index empty: clearing search.indexVersion, so OpenMRS rebuilds it"
  mysql -h "$DB_HOST" -u "$DB_USER" "$DB_NAME" -e "DELETE FROM global_property WHERE property = 'search.indexVersion'"
fi
unset MYSQL_PWD

# The reports' migrations, as their package's install runs them (a new bahmni_reports database needs them)
reports_liquibase() { # <changelog> <database> <user> <password>
  (cd /opt/bahmni-reports/bahmni-reports/WEB-INF/classes \
    && /usr/java/default/bin/java -Dliquibase.databaseChangeLogTableName=liquibasechangelog \
         -Dliquibase.databaseChangeLogLockTableName=liquibasechangeloglock -DschemaName="$2" \
         -jar ../lib/liquibase-core-2.0.5.jar --driver=com.mysql.jdbc.Driver \
         --classpath=../lib/mysql-connector-java-5.1.26.jar --changeLogFile="$1" \
         --url="jdbc:mysql://$DB_HOST:3306/$2" --username="$3" --password="$4" update) \
    >> /bahmni_temp/logs/reports-liquibase.log 2>&1
}
migrations_failed() {
  echo "ERROR: the reports' migrations ($1) failed:" >&2
  grep -vE '^\s+at ' /bahmni_temp/logs/reports-liquibase.log | tail -n 15 >&2
  exit 1
}
echo "Running the reports' migrations"
# Only their own database's. Their changesets in the openmrs database (liquibase.xml) ran when the server
# installed the package, and one of them (Reports-170220160455) fails on the server's data (two users named
# reports-user); the server has never run them at start either.
# The reports' account is made by the instance's openmrs-db-accounts, which can still be running
for i in $(seq 1 60); do
  MYSQL_PWD=$REPORTS_DB_PASSWORD mysql -h "$DB_HOST" -u "$REPORTS_DB_USER" bahmni_reports -e 'select 1' >/dev/null 2>&1 && break
  [ "$i" -eq 60 ] && { echo "ERROR: can't log in to bahmni_reports as $REPORTS_DB_USER" >&2; exit 1; }
  sleep 2
done
reports_liquibase liquibase_bahmni_reports.xml bahmni_reports "$REPORTS_DB_USER" "$REPORTS_DB_PASSWORD" \
  || migrations_failed bahmni_reports

# --- Logs: Apache writes to the container's log itself. The Java services, which run as bahmni and can't,
# log to files (rotated by log4j, and logrotate for their console output and the batch exports'), shown in the
# container's log from
# here on. Polling: this tail (coreutils 8.4) with inotify never picks up a file created after it starts,
# as these are on a new container's first start and after each rotation.
tail ---disable-inotify -s 1 -n 0 -F /opt/openmrs/log/openmrs.log /opt/openmrs/log/openmrs-console.log \
  /opt/bahmni-reports/log/bahmni-reports.log /opt/bahmni-reports/log/bahmni-reports-console.log \
  /opt/bahmni-batch/log/bahmni-batch.log 2>/dev/null &

# --- Services
http_code() { curl -s -o /dev/null -w '%{http_code}' "http://localhost:8050$1"; }
wait_for_modules() {
  echo "Waiting for OpenMRS modules"
  for i in $(seq 1 180); do
    [ "$(http_code '/openmrs/ws/rest/v1/bahmnicore/sql/globalproperty?property=locale.allowed.list')" = 200 ] && return 0
    sleep 5
  done
  return 1
}

# The pid files (start.sh) from an earlier start of this container
rm -f /opt/openmrs/run/openmrs.pid /opt/bahmni-reports/run/bahmni-reports.pid
service openmrs start
service bahmni-reports start
wait_for_modules || { echo "ERROR: OpenMRS's modules didn't start" >&2; exit 1; }
echo "Legacy UI login page: HTTP $(http_code /openmrs/login.htm)"
# Apache last: it answers the healthcheck, and nothing reaches OpenMRS through it while it's starting
if [ "${OMRS_APACHE_ACCESS_LOG:-false}" = true ]; then
  echo 'OPTIONS="-D ACCESS_LOG"' > /etc/sysconfig/httpd
  echo "Apache access log enabled (OMRS_APACHE_ACCESS_LOG=true)"
fi
service httpd start
# Apache's disk cache (site.conf) has no limit of its own
htcacheclean -d 60 -n -t -i -l 500M -p /var/cache/mod_proxy

# Cron: logrotate (the Java services' console output, the batch exports' log) and, as scheduled on the
# server, the nightly endTB exports
if [ "${OMRS_BATCH_EXPORTS:-true}" = false ]; then
  rm -f /var/spool/cron/bahmni
  echo "Batch exports disabled (OMRS_BATCH_EXPORTS=false)"
fi
service crond start

# Until OpenMRS or the reports stop: the container then exits, and Docker restarts it
openmrs_pid=$(cat /opt/openmrs/run/openmrs.pid)
reports_pid=$(cat /opt/bahmni-reports/run/bahmni-reports.pid)
while kill -0 "$openmrs_pid" 2>/dev/null && kill -0 "$reports_pid" 2>/dev/null; do
  sleep 10 & wait $!
done
echo "ERROR: OpenMRS or the reports stopped" >&2
exit 1
