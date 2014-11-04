#!/usr/bin/env bash

# $1 = user to run scripts as
# $CF_DB_HOST = (optional) host for congress-forms database

# stop setup script if any command fails
set -e

if [ "ubuntu" != $1 ]
then
  # because ec2 needs to jigger its homunculi
  sleep 30
fi

cd /vagrant

if [ ! -z $CF_DB_HOST ]
then
	sed -i "s/localhost/$CF_DB_HOST/g" /vagrant/config/database.rb
	su -c "source /home/$1/.rvm/scripts/rvm; rvm use ruby-2.1.0;
	gem install bundler -v '= 1.5.1'; gem install json -v '1.8.1';
	rvm gemset create congress-forms; rvm alias create congress-forms ruby-2.1.0@congress-forms; 
	bundle install --path /home/$1/.rvm/gems/ruby-2.1.0@congress-forms/gems/;" "$1"
fi

echo "Setting up PhantomJS..."
cd /home/$1/
curl -Lo phantomjs.tar.bz2 https://bitbucket.org/ariya/phantomjs/downloads/phantomjs-1.9.7-linux-x86_64.tar.bz2
tar -jxvf phantomjs.tar.bz2 > /dev/null

sudo ln -s /home/$1/phantomjs-1.9.7-linux-x86_64/bin/phantomjs /usr/bin/phantomjs

echo "Installing rsyslog"
curl -Lo remote-syslog.tar.gz https://github.com/papertrail/remote_syslog2/releases/download/v0.13/remote_syslog_linux_amd64.tar.gz
tar -zxvf remote-syslog.tar.gz > /dev/null
sudo ln -s /home/$1/remote_syslog/remote_syslog /usr/bin/remote_syslog

echo "Installing dispatcher"
cd /vagrant/congress-forms-dispatcher
npm install

sudo chmod go-w /vagrant
sudo chown "$1:$1" /vagrant

echo -e "\n\nYou're all done!  Now type 'vagrant ssh', cd into /vagrant, and type 'bundle exec rackup' to run!"
