# The image

The Kazakhstan EMR (Bahmni 0.89, OpenMRS 2.1) as the server ran it, as an image for an `openmrs_docker`
instance.

Inside, the image is still CentOS 6, with what the server has installed and `../config` as `bahmni_config`.
It holds no credentials and no patient data.

## What's in it

| Part | From | Compared with the server |
| --- | --- | --- |
| Bahmni 0.89's packages: `bahmni-openmrs-0.89-89`, `-emr-0.89-326`, `-web-0.89-326`, `-reports-0.89-64`, `-implementer-interface-0.89-97` | [Bahmni's RPM repo](https://repo.mybahmni.org/releases/) | The server's installed versions; its files match the packages' apart from its config (`system/`) |
| OpenMRS 2.1.0's war and the 29 omods | `../openmrs-distro.properties`, fetched from Maven by the OpenMRS SDK's `build-distro`; `bahmniendtb` downloaded directly (`../pom.xml`), as its published pom can't be resolved | Same classes and resources as the server's. Its SNAPSHOT builds are the `-endtb-1` releases; its `bahmniendtb` 2.4.0-SNAPSHOT is 2.3.3 with another version string |
| endTB's frontend build | `endtb-bahmniapps-0.89-46.zip`, a release asset of [endtb/openmrs-module-bahmniapps](https://github.com/endtb/openmrs-module-bahmniapps/releases/tag/2.3.3) | Same. The server had edited its translations: older copies of four English files (missing translations the build has, so not used), and Russian translations, which are in `../config/openmrs/i18n` |
| `system/` | The server: its changes to the packages' config files, `bahmni.conf`, its site, served as plain HTTP (`etc/httpd/conf.d/site.conf`, from its HTTPS site without TLS; its `httpd.conf` without port 80), its root page (`var/www/html/index.html`, which Bahmni's installer renders for each server) and `cgi-bin/systemdate` | The server's files with their credentials blank (the entrypoint sets them from env), and `JAVA_HOME` set to the JRE below |
| The maintenance page (`maintenance.html` and its images) | `bahmni-installer-0.89-193` from Bahmni's RPM repo (its playbooks' `httpd-maintenance` files; the package isn't installed) | The same |
| endTB's batch exports (`bahmni-batch` 2.4.2) | The jar from [endtb/bahmni-endtb-batch](https://github.com/endtb/bahmni-endtb-batch/releases/tag/2.4.2)'s release; its wrapper script and schedule from the server (`system/opt/bahmni-batch`, `system/var/spool/cron/bahmni`) | The same jar contents. The server's script names the stemTB export "STEM TB" |
| Java 8: Temurin 8u504 | [Adoptium](https://adoptium.net) | The server ran Oracle's 8u131 |

OpenMRS and Bahmni reports run in the Tomcat built into Bahmni's launcher jars (`/opt/openmrs/lib/openmrs.jar`,
`/opt/bahmni-reports/lib/bahmni-reports.jar`): Tomcat 8.0.12.

## How it fits an openmrs_docker instance

The instance's `openmrs` service ([openmrs-contrib-distro-tools](https://github.com/PIH/openmrs-contrib-distro-tools)
`services/openmrs/compose.yaml`) runs this image, and `openmrs-db` runs MySQL 5.6, its default.

| The service expects | The image |
| --- | --- |
| HTTP on 8080 | Apache on 8080: the server's site without TLS. `/bahmni`, `bahmni_config` and documents are served by it; `/openmrs` and `/bahmnireports` go to OpenMRS (8050) and Bahmni reports (8051) in the same container. The instance's proxy terminates TLS |
| `/openmrs/health/started` | Answered by OpenMRS through Apache, which starts only once OpenMRS's modules have. If OpenMRS or the reports stop, the container exits and Docker restarts it |
| `OMRS_CONFIG_CONNECTION_*` | Written into OpenMRS's, the reports' and Bahmni's scripts' config at start |
| `/openmrs/data` | OpenMRS's application data directory (search index, complex obs, caches; the modules are in the image), with `/home/bahmni` (documents, patient images, uploads, report outputs) as `/openmrs/data/bahmni` |
| `TZ` | The container's time zone |

The instance's env needs, besides the usual settings (lines starting `OMRS_` reach the container):

```bash
OPENMRS_DB_USER='openmrs-user'
# The reports' own database
OPENMRS_DB_ACCOUNT_REPORTS_USER='reports-user'
OPENMRS_DB_ACCOUNT_REPORTS_PASSWORD='<password>'
OPENMRS_DB_ACCOUNT_REPORTS_GRANTS='ALL ON bahmni_reports.*'
OPENMRS_DB_ACCOUNT_REPORTS_DATABASES='bahmni_reports'
OMRS_REPORTS_DB_PASSWORD='<the same password>'
# The OpenMRS user the reports log in as (reports-user), with its password in the database
OMRS_REPORTS_OPENMRS_PASSWORD='<password>'
TZ='Etc/GMT-5'
# Optional: the nightly endTB exports run as on the server (stemTB at 02:30, everything at 23:30); this turns them off
# OMRS_BATCH_EXPORTS='false'
# Optional: Apache's access log in the container's log (off: every page load is dozens of requests)
# OMRS_APACHE_ACCESS_LOG='true'
```

At each start the entrypoint runs the reports' migrations (as their package's install did), which
creates the `bahmni_reports` tables in a new database. If the search index is empty (a new volume or a
restored dump), it clears `search.indexVersion`, so OpenMRS rebuilds the index.

## Building

```bash
mvn package                              # the image kazakhstan-emr:<version>
mvn package -Ddocker.image.name=<name> -Ddocker.image.tag=<tag>
mvn package -Ddocker.skip                # only target/distro/web, the Docker build context
```

The SDK's `build-distro` puts the war and the omods (`../openmrs-distro.properties`) in `target/distro/web`;
Maven adds the endTB module, the Bahmni packages, the frontend and batch export builds and the JRE (each
download checked against its SHA-256), this directory (its Dockerfile replacing the SDK's) and `../config`,
then builds the image from there. CI (`../.github/workflows/build.yml`) builds pull requests, and pushes `main`'s image to Docker Hub as
`partnersinhealth/kazakhstan-emr` (with openmrs-contrib-distro-tools' `build-and-push-docker` action).

## Moving the server's data

The database: the server's `openmrs` dump, without its `DEFINER` clauses (the dump's procedures name
`openmrs-user@localhost`, which the instance doesn't have):

```bash
openmrs-utils strip-mysqldump-definers --path=db-openmrs.sql.gz --output=db-openmrs.nodefiners.sql.gz
```

`/home/bahmni` (documents, patient images, uploads, report outputs, exports) goes into the
`openmrs-data` volume as `bahmni/`. On the server, archive it inside an `openmrs-data/` folder
(`initialize` restores the contents of an archive's single top-level folder), without `backups/`
(the server's own database backups):

```bash
tar -czf /tmp/openmrs-data.tar.gz -C /home --exclude=bahmni/backups \
  --transform='s,^bahmni,openmrs-data/bahmni,S' bahmni
```

(`--transform` puts it under `openmrs-data/`, not the links inside it, which stay as they are; the
server's tar is 1.23.) Then both volumes in one go, from a folder holding an entry per service (links
work), named as `initialize` expects:

```bash
mkdir restore
ln -s "$PWD/db-openmrs.nodefiners.sql.gz" restore/openmrs-db.sql.gz
ln -s "$PWD/openmrs-data.tar.gz" restore/openmrs.tar.gz
openmrs-docker <instance> initialize --from restore
```

The server's `/home/bahmni/.OpenMRS/openmrs-runtime.properties` holds its credentials; the entrypoint
replaces it with a link to the image's.

Nothing else: OpenMRS's application data directory on the server (`/opt/openmrs`) held no data apart from its
search index (no `complex_obs` or `hl7_archives`), which OpenMRS rebuilds on the first start.

## Backing up an instance

`openmrs-utils backup-openmrs-data-directory`, leaving out the links the entrypoint puts in
`/openmrs/data` to the image's config (it refuses links pointing outside the volume, and recreates
these on every start), with the instance stopped:

```bash
openmrs-docker <instance> stop
openmrs-utils backup-openmrs-data-directory --volume=<instance>_openmrs-data \
  --output=openmrs-data.tar.gz --exclude-distribution-artifacts \
  --exclude=bahmni_config --exclude=bahmnicore.properties \
  --exclude=obscalculator --exclude=ordertemplates --exclude=encounterModifier \
  --exclude=patientMatchingAlgorithm --exclude=elisFeedInterceptor \
  --exclude=bahmni/.OpenMRS/openmrs-runtime.properties \
  --exclude=bahmni/.OpenMRS/bahmnicore.properties --exclude=bahmni/.OpenMRS/modules \
  --exclude=bahmni/.bahmni-reports/bahmni-reports.properties
openmrs-docker <instance> start
```

It restores like the server's archive (an `openmrs.tar.gz` entry in the `initialize --from` folder).

## Local copies

On a copy of the server's database (never on the server), to log in as `superman` / `Admin123`: this sets that
password, un-retires the account and clears a login lockout, and says whether the account exists.

```bash
docker exec <instance>-openmrs-db sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -uroot openmrs -e "
SET @salt = SHA2(UUID(), 512);
UPDATE users SET salt = @salt, password = SHA2(CONCAT(\"Admin123\", @salt), 512), retired = 0 WHERE username = \"superman\";
DELETE FROM user_property WHERE property IN (\"loginAttempts\", \"lockoutTimestamp\") AND user_id = (SELECT user_id FROM users WHERE username = \"superman\");
SELECT ROW_COUNT() AS lockout_rows_cleared, (SELECT COUNT(*) FROM users WHERE username = \"superman\") AS superman_exists;"'
```

## Logs

Everything is in the container's log (`openmrs-docker <instance> logs openmrs`), from the start of OpenMRS's
start-up. Apache writes its error log there itself, and its access log only with `OMRS_APACHE_ACCESS_LOG=true`
(the proxy in front sees every request); the server piped both to `rotatelogs`, which never removed old files. OpenMRS, the reports and the batch exports run as
`bahmni` and log to files, as on the server (`/opt/openmrs/log`, `/opt/bahmni-reports/log`,
`/opt/bahmni-batch/log`), which the entrypoint shows in the container's log as they're written. They're
bounded: log4j rotates OpenMRS's and the reports' logs (10 × 10 MB), and logrotate the batch exports' log and
OpenMRS's and the reports' console output (5 × 10 MB each). The console output has its own files
(`*-console.log`, from their `start.sh`): on the server it was appended to the log4j file, and after log4j
rotated that file it went on growing, deleted, until Java restarted.

## Batch exports

`bahmni-batch` writes the export zips to `/home/bahmni/endtb_export` and their list, the page the Exports tile
opens, to `bahmni_config/report.html`, a link to `endtb_export/report.html`; both are in `/openmrs/data`.
Run one by hand with `bahmni-batch [belongs_to_external_cohort=stemTB]` as user `bahmni`.

The exports are trimmed before each one runs (`prune-exports.sh`, in the crontab): for each job, the last export
of each month is kept for the newest 18 months, with the newest export always among them, and every other zip
goes, with its run's history in the database. Each job's newest run is kept too, so a failed export stays on
the page until the job next succeeds. With the run that follows, each job has at most 20, the most the page
lists, so the page lists every zip there is. On the server the zips accumulated until the disk filled.

## Not in the image

The server's other cron jobs: three reboots a day "to free up memory", nightly database backups to
`/home/bahmni/backups`, a nightly Apache restart, and its certificate renewal. TLS and backups are the
instance host's.
