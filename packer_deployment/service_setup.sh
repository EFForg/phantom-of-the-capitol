#!/usr/bin/env bash

echo "Creating Upstart Script for Congress-Forms"
sudo cp /$1/packer_deployment/upstart-congress-forms.conf /etc/init/upstart-congress-forms.conf