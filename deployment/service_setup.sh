#!/usr/bin/env bash

echo "Adding destination to rsyslog_config"
echo "destination:" >> /vagrant/deployment/log_files.yml
echo "  port: $RSYSLOG_PORT" >> /vagrant/deployment/log_files.yml
echo "  host: $RSYSLOG_HOST" >> /vagrant/deployment/log_files.yml
echo "  protocol: tls" >> /vagrant/deployment/log_files.yml

echo "Upstarting logger"
sudo cp /vagrant/deployment/upstart-congress-forms-logger.conf /etc/init/upstart-congress-forms-logger.conf
sudo start upstart-congress-forms-logger

echo "Creating Upstart Script for Congress-Forms"
sudo cp /vagrant/deployment/upstart-congress-forms.conf /etc/init/upstart-congress-forms.conf
sudo start upstart-congress-forms

echo "Upstarting dispatcher"
sudo cp /vagrant/deployment/congress-forms-dispatcher.conf /etc/init
sudo start congress-forms-dispatcher
