#!/usr/bin/env bash

sudo -i

echo "Creating Upstart Script for Congress-Forms"
cp /vagrant/deployment/upstart-congress-forms.conf /etc/init/upstart-congress-forms.conf
start upstart-congress-forms

echo env RSYSLOG_PORT=$RSYSLOG_PORT > /etc/init/upstart-congress-forms-logger.conf
echo env RSYSLOG_HOST=$RSYSLOG_HOST >> /etc/init/upstart-congress-forms-logger.conf
cat /vagrant/deployment/upstart-congress-forms-logger.conf >> /etc/init/upstart-congress-forms-logger.conf
start upstart-congress-forms-logger
