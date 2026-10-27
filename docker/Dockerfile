# The Kazakhstan EMR (Bahmni 0.89, on CentOS 6) as the server ran it, as an image for an
# openmrs_docker instance (openmrs-contrib-distro-tools docker/services/openmrs.yaml): HTTP on 8080,
# the database settings from OMRS_* env, data in /openmrs/data. See README.md.
#
# Built by Maven (../pom.xml) from target/distro/web:
#   openmrs_core/, openmrs_modules/   the OpenMRS war and the omods (../openmrs-distro.properties, by the SDK's
#                                     build-distro, and the endTB module)
#   downloads/   Bahmni 0.89's packages, endTB's frontend and batch export builds, the JRE
#   system/      the server's own changes to the packages' files, and its Apache site (no credentials)
#   config/      the site's config
FROM centos:6

# CentOS 6 mirrors are gone. Packages come from the vault, still checked against the CentOS key.
RUN sed -i -e 's/^mirrorlist=/#mirrorlist=/' \
      -e 's#^\#\?baseurl=http://mirror.centos.org/centos/\$releasever#baseurl=http://vault.centos.org/6.10#' \
      /etc/yum.repos.d/CentOS-Base.repo \
 && yum -y -q install initscripts chkconfig httpd mod_wsgi unzip cronie python-setuptools \
      tar gzip which perl net-tools openssl mysql fontconfig dejavu-sans-fonts dejavu-serif-fonts dejavu-sans-mono-fonts \
 && yum clean all
# Same IDs as on the server
RUN groupadd -g 501 bahmni && useradd -u 501 -g bahmni -d /home/bahmni -s /sbin/nologin bahmni

# The downloads are mounted, not copied, where they're unpacked, and each file is owned as it's created, so the
# image holds each file once.

# Java 8, where the packages' scripts expect it (system/ sets their JAVA_HOME to /usr/java/default)
RUN --mount=type=bind,source=downloads,target=/tmp/downloads \
    mkdir -p /usr/java && tar -C /usr/java -xzf /tmp/downloads/jre.tar.gz \
 && ln -s /usr/java/$(ls /usr/java | head -1) /usr/java/default \
 && /usr/java/default/bin/java -version

# Bahmni's packages: their files only, owned by bahmni as their install scripts leave them, with the OpenMRS war
# and modules from openmrs-distro.properties (the war is the package's; the modules, the server's) and endTB's
# frontend build in place of the packages' own. What else their install scripts do (apart from the database)
# follows.
RUN --mount=type=bind,source=downloads,target=/tmp/downloads \
    --mount=type=bind,source=openmrs_core,target=/tmp/openmrs_core \
    --mount=type=bind,source=openmrs_modules,target=/tmp/openmrs_modules \
    rpm -i --nodeps --noscripts /tmp/downloads/*.rpm \
 && cp -f /tmp/openmrs_core/openmrs.war /opt/openmrs/openmrs.war \
 && mkdir -p /opt/openmrs/openmrs && (cd /opt/openmrs/openmrs && unzip -q -o ../openmrs.war) \
 && mkdir -p /opt/openmrs/openmrs/WEB-INF/classes \
 && cp /opt/openmrs/etc/log4j.xml /opt/openmrs/openmrs/WEB-INF/classes/ \
 && cp -f /opt/openmrs/etc/web.xml /opt/openmrs/openmrs/WEB-INF/ \
 && rm -rf /opt/openmrs/modules && cp -r /tmp/openmrs_modules /opt/openmrs/modules \
 && rm -rf /opt/bahmni-web/etc/bahmniapps && mkdir /opt/bahmni-web/etc/bahmniapps \
 && unzip -q /tmp/downloads/bahmniapps.zip -d /opt/bahmni-web/etc/bahmniapps \
 && chown -R bahmni:bahmni /opt/openmrs /opt/bahmni-web /opt/bahmni-reports

# bahmni-openmrs
RUN mkdir -p /bahmni_temp/logs \
 && ln -s /opt/openmrs/etc /etc/openmrs \
 && ln -s /opt/openmrs/bin/openmrs /etc/init.d/openmrs \
 && ln -s /opt/openmrs/run /var/run/openmrs \
 && ln -s /opt/openmrs/openmrs /var/run/openmrs/openmrs \
 && ln -s /opt/openmrs/log /var/log/openmrs \
 && chown -R bahmni:bahmni /bahmni_temp \
 && chkconfig --add openmrs
# bahmni-emr
RUN mkdir -p /home/bahmni/.OpenMRS /home/bahmni/patient_images /home/bahmni/document_images \
      /home/bahmni/uploaded-files/mrs /home/bahmni/uploaded_results \
 && ln -sfn /opt/openmrs/modules /home/bahmni/.OpenMRS/modules \
 && ln -sfn /opt/openmrs/bahmnicore.properties /home/bahmni/.OpenMRS/bahmnicore.properties \
 && ln -sfn /opt/openmrs/etc/openmrs-runtime.properties /home/bahmni/.OpenMRS/openmrs-runtime.properties \
 && cp -f /opt/openmrs/etc/blank-user.png /home/bahmni/patient_images/blank-user.png \
 && cp -f /opt/openmrs/etc/emr_ssl.conf /etc/httpd/conf.d/emr_ssl.conf
# The modules' web files, where the modules copy them into the webapp when they start (and the legacy UI's
# tag libraries, tags and page templates also into WEB-INF): Tomcat reads tag libraries only when the webapp
# starts, so on a new container the legacy UI wouldn't compile until OpenMRS restarted. (On the server they
# were already there.)
RUN w=/opt/openmrs/openmrs/WEB-INF && x=/tmp/omod \
 && for m in /opt/openmrs/modules/*.omod; do \
      id=$(unzip -p $m config.xml | sed -n 's#.*<id>\(.*\)</id>.*#\1#p' | head -1); \
      rm -rf $x && mkdir $x && { unzip -q $m 'web/module/*' -d $x || [ $? -eq 11 ]; } || exit 1; \
      [ -d $x/web/module ] || continue; \
      mkdir -p $w/view/module/$id && cp -r $x/web/module/. $w/view/module/$id/; \
      if [ -d $x/web/module/tags ]; then mkdir -p $w/tags/module && cp -r $x/web/module/tags $w/tags/module/$id; fi; \
      if [ $id = legacyui ]; then cp -r $x/web/module/taglibs $x/web/module/template $w/ && cp -r $x/web/module/tags/. $w/tags/; fi; \
    done \
 && rm -rf $x && find $w ! -user bahmni -exec chown -h bahmni:bahmni {} +
# bahmni-web
RUN mkdir -p /var/cache/mod_proxy /var/log/client-side-logs \
 && touch /var/log/client-side-logs/client-side.log \
 && chown -R apache:apache /var/cache/mod_proxy /var/log/client-side-logs \
 && ln -sfn /opt/bahmni-web/etc/client_side_logging/ /usr/lib/python2.6/site-packages/client_side_logging \
 && ln -sfn /opt/bahmni-web/etc /etc/bahmni-web \
 && ln -sfn /opt/bahmni-web/etc/bahmniapps /var/www/bahmniapps \
 && ln -sfn /opt/bahmni-web/etc/client_side_logging /var/www/client_side_logging \
 && ln -sfn /opt/bahmni-web/etc/offlineMetadata.json /var/www/html/offlineMetadata.json \
 && mkdir -p /var/www/bahmni_revisions /var/www/implementation_config
# bahmni-reports
RUN ln -s /opt/bahmni-reports/etc /etc/bahmni-reports \
 && ln -s /opt/bahmni-reports/bin/bahmni-reports /etc/init.d/bahmni-reports \
 && ln -s /opt/bahmni-reports/run /var/run/bahmni-reports \
 && ln -s /opt/bahmni-reports/bahmni-reports /var/run/bahmni-reports/bahmni-reports \
 && ln -s /opt/bahmni-reports/log /var/log/bahmni-reports \
 && mkdir -p /home/bahmni/.bahmni-reports /home/bahmni/reports \
 && ln -sfn /opt/bahmni-reports/etc/bahmni-reports.properties /home/bahmni/.bahmni-reports/bahmni-reports.properties \
 && cp -f /opt/bahmni-reports/etc/bahmni_reports_ssl.conf /etc/httpd/conf.d/bahmni_reports_ssl.conf \
 && chkconfig --add bahmni-reports
# bahmni-implementer-interface
RUN ln -sfn /opt/bahmni-implementer-interface/etc/implementer_interface /var/www/implementer_interface \
 && cp -f /opt/bahmni-implementer-interface/etc/implementer_interface_ssl.conf /etc/httpd/conf.d/

# bahmni-endtb-batch, endTB's exports: as its package installs it. The server's schedule for it is
# system/var/spool/cron/bahmni; entrypoint.sh removes it when OMRS_BATCH_EXPORTS=false.
COPY --chown=bahmni:bahmni downloads/bahmni-batch-*.jar /opt/bahmni-batch/libs/
RUN mkdir -p /opt/bahmni-batch/conf /opt/bahmni-batch/log /home/bahmni/endtb_export \
 && ln -s /usr/java/default/bin/java /usr/bin/java \
 && ln -sfn /opt/bahmni-batch/bin/bahmni-batch /usr/bin/bahmni-batch \
 && ln -sfn /opt/bahmni-batch/log /var/log/bahmni-batch \
 && ln -sfn /home/bahmni/endtb_export /opt/bahmni-batch/endtb_export

# The maintenance page (served while /var/www/html/maintenance.enable exists), from the installer's playbooks
RUN --mount=type=bind,source=downloads/installer,target=/tmp/installer \
    cd / && rpm2cpio /tmp/installer/bahmni-installer-*.rpm | cpio -idm --quiet \
      './opt/bahmni-installer/bahmni-playbooks/roles/httpd-maintenance/files/*' \
 && for f in maintenance.html src.jpg bahmni-logo.png; do \
      mv /opt/bahmni-installer/bahmni-playbooks/roles/httpd-maintenance/files/$f /var/www/html/; done \
 && rm -rf /opt/bahmni-installer

# The server's own files: its changes to the packages' config (credentials blank: entrypoint.sh sets
# them from env), its site (served as plain HTTP on 8080: conf.d/site.conf), pages and CGI script
COPY system/ /
RUN ln -sfn /opt/bahmni-web/etc/httpd.conf /etc/httpd/conf/httpd.conf \
 && httpd -t \
 && chmod 755 /var/www/cgi-bin/systemdate /opt/bahmni-batch/bin/bahmni-batch \
 && chmod 744 /opt/openmrs/bin/start.sh /opt/bahmni-reports/bin/start.sh

# The site's config
COPY --chown=bahmni:bahmni config/ /var/www/bahmni_config/
# The exports' list (the Exports tile's page), which bahmni-batch writes there, kept with the exports
RUN ln -s /home/bahmni/endtb_export/report.html /var/www/bahmni_config/report.html \
 && chown bahmni:bahmni /var/spool/cron/bahmni && chmod 600 /var/spool/cron/bahmni

# No credentials: every password-like setting in the services' config is empty
RUN ! grep -lIiE '^\s*(export\s+)?[A-Za-z_.]*(password|passwd)\s*=\s*[^[:space:]]' \
      /opt/openmrs/etc/* /opt/openmrs/bahmnicore.properties /opt/bahmni-reports/etc/* \
      /opt/bahmni-web/etc/*.conf /etc/bahmni-installer/*

# Data in /openmrs/data (the instance's openmrs-data volume): OpenMRS's application data directory
# (system/opt/openmrs/etc/openmrs-runtime.properties; the modules stay in /opt/openmrs/modules), with
# /home/bahmni in it. The entrypoint creates what's missing there.
RUN mv /home/bahmni /opt/home-bahmni-skel \
 && ln -s /openmrs/data/bahmni /home/bahmni \
 && rm -f /etc/localtime

COPY entrypoint.sh /usr/local/sbin/entrypoint.sh
COPY prune-exports.sh /usr/local/sbin/prune-exports
# What the steps since the packages added to the services' directories (only those files: a chown -R would
# copy the packages into another layer)
RUN chmod 755 /usr/local/sbin/entrypoint.sh /usr/local/sbin/prune-exports \
 && find /opt/openmrs /opt/bahmni-web /opt/bahmni-reports /opt/bahmni-batch /opt/home-bahmni-skel /bahmni_temp \
      /var/www/bahmni_config /var/www/implementation_config ! -user bahmni -exec chown -h bahmni:bahmni {} +

EXPOSE 8080
ENTRYPOINT ["/usr/local/sbin/entrypoint.sh"]
