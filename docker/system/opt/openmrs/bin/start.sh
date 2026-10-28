#!/bin/sh
# UTF-8, as on the server, whose services started at boot with LANG from /etc/sysconfig/i18n (service clears it)
export LANG=en_US.UTF-8
nohup $JAVA_HOME/bin/java -jar $SERVER_OPTS /opt/openmrs/lib/openmrs.jar >> /var/log/openmrs/openmrs-console.log 2>&1 &
echo $! > /var/run/openmrs/openmrs.pid
