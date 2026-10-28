#!/bin/sh
# UTF-8, as on the server, whose services started at boot with LANG from /etc/sysconfig/i18n (service clears it)
export LANG=en_US.UTF-8
nohup $JAVA_HOME/bin/java -jar $SERVER_OPTS /opt/bahmni-reports/lib/bahmni-reports.jar >> /var/log/bahmni-reports/bahmni-reports-console.log 2>&1 &
echo $! > /var/run/bahmni-reports/bahmni-reports.pid
