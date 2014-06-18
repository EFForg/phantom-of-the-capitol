#!/usr/bin/env bash

echo "Creating Upstart Script for Congress-Forms"
sudo cp /vagrant/packer_deployment/upstart-congress-forms.conf /etc/init/upstart-congress-forms.conf
sudo start upstart-congress-forms