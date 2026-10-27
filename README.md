# kazakhstan-emr

The EMR for Kazakhstan: Bahmni 0.89 (OpenMRS 2.1) with endTB's modules and frontend, run as an `openmrs_docker` instance (`docker/`). This repo holds what's needed to build and
run it: what's here is what runs.

## Layout

| Path | What |
| --- | --- |
| `config/` | The site's Bahmni config (`bahmni_config`): frontend app config, translations, report SQL, Groovy extensions, and the endTB database migrations (`openmrs/migrations`) |
| `docker/` | The server as it runs today, as an image for an `openmrs_docker` instance on a current host: the Dockerfile and the server's own files. See its README |
| `openmrs-distro.properties` | The OpenMRS war and the omods, as for other OpenMRS distributions (fetched by the OpenMRS SDK's `build-distro`) |
| `pom.xml` | Builds the image (`mvn package`): the SDK's `build-distro` and the other downloads, into `target/distro/web`, then the image from there |
| `e2e/` | Playwright UI checks |

## Where the config came from

The server's `/var/www/bahmni_config` (from its archive, 2026-10-26). It began as a checkout of
[endtb/stem-tb](https://github.com/endtb/stem-tb) `kazakhstan/stemtb_config`, with changes made only on the
server since: the mental-health reports, dashboard and app config, translations, a Groovy file.

Left out: backup and editor files (`*_bak`, `*_swp`, `*_orig`, `.sql1`, `openmrs.iml`, `i18n_bak/`),
copies of `i18n/` nested inside itself, `automatedTests/` notes, the concept upload templates
(`templates/`), the stem-tb repo's own tooling (`playbooks/`, `scripts/`, `.tx/`, its README), what the
server writes there (`report.html`, the endTB exports' list that the Exports tile opens, and
`migration-run-log.txt`), `saePVUnitImport/` (a spreadsheet template) and `dbdump/`.

Not included: the Initializer concept CSVs (package1, pih-mental-health forms) the server loaded in 2021. Its
concept dictionary was changed after that, and re-running them would undo those changes. The DB is the
source of truth for concepts; recreate CSVs from it if they're ever wanted.

## UI checks

`e2e/` logs in as a local test user and only opens a fake test patient (`KZS-999-99999`, created by the
tests), never real patients' pages. Not for the production server.

```bash
mysql openmrs < e2e/e2e-user.sql      # on a copy, never the server
cd e2e && npm install && npx playwright install chromium && BASE_URL=https://<host> npx playwright test
```

They cover login and home tiles, dashboard tabs, every obs form, saving Treatment Initiation (Patient
Monitoring schedule), Baseline (BMI) and a Mental Health Visit, ordering a TB drug (Drug-O-Gram), the
Reports list and running a report (only that a file comes back, over the test patient's visit date), new
patient registration and the Russian locale.
