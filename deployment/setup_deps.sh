#!/usr/bin/env bash

# $1 = user to run scripts as

# stop setup script if any command fails
set -e

DEPENDENCIES="curl imagemagick libmysql++-dev libpq-dev git libqt4-dev xvfb"
su -c "sudo apt-get update; sudo apt-get -y install $DEPENDENCIES" "$1"
echo Installing node.js
curl -sL https://deb.nodesource.com/setup | bash -
apt-get -y install nodejs
su -c "gpg --keyserver hkp://keys.gnupg.net --recv-keys D39DC0E3 && curl -sSL https://get.rvm.io | bash -s stable; source /home/$1/.rvm/scripts/rvm; rvm install ruby-2.1.0" "$1"
