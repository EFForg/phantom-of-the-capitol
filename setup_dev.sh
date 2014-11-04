#!/usr/bin/env bash

# $1 = user to run scripts as
# $CF_DB_HOST = (optional) host for congress-forms database

# stop setup script if any command fails
set -e

random() {
    head -c $1 /dev/urandom | base64
}

mysql_root=$(random 20)
sudo debconf-set-selections <<EOF
	mysql-server-5.5 mysql-server/root_password password $mysql_root
	mysql-server-5.5 mysql-server/root_password_again password $mysql_root
EOF

cd /vagrant

if [ "ubuntu" != $1 ]
then
    DEPENDENCIES="mysql-server curl imagemagick libmysql++-dev libpq-dev git libqt4-dev xvfb"
    su -c "sudo apt-get update; sudo apt-get -y install $DEPENDENCIES" "$1"
    echo Installing node.js
    curl -sL https://deb.nodesource.com/setup | bash -
    apt-get -y install nodejs
    su -c "gpg --keyserver hkp://keys.gnupg.net --recv-keys D39DC0E3 && curl -sSL https://get.rvm.io | bash -s stable; source /home/$1/.rvm/scripts/rvm; rvm install ruby-2.1.0" "$1"
else
    # because ec2 needs to jigger its homunculi
    sleep 30
fi

if [ ! -z $CF_DB_HOST ]
then
	sed -i "s/localhost/$CF_DB_HOST/g" /vagrant/config/database.rb
	su -c "source /home/$1/.rvm/scripts/rvm; rvm use ruby-2.1.0;
	gem install bundler -v '= 1.5.1'; gem install json -v '1.8.1';
	rvm gemset create congress-forms; rvm alias create congress-forms ruby-2.1.0@congress-forms; 
	bundle install --path /home/$1/.rvm/gems/ruby-2.1.0@congress-forms/gems/;" "$1"
else
	mysql -u root -p"$mysql_root" -e "create database if not exists congress_forms_development;  GRANT ALL PRIVILEGES ON congress_forms_development.* TO 'congress_forms'@'localhost';"
	mysql -u root -p"$mysql_root" -e "create database if not exists congress_forms_test;  GRANT ALL PRIVILEGES ON congress_forms_test.* TO 'congress_forms'@'localhost';"
	su -c "source /home/$1/.rvm/scripts/rvm; rvm use ruby-2.1.0;
	gem install bundler -v 1.5.1;
	rvm gemset create congress-forms; rvm alias create congress-forms ruby-2.1.0@congress-forms; 
	bundle install --path /home/$1/.rvm/gems/ruby-2.1.0@congress-forms/gems/; 
	echo \"Loading schema...\"; bundle exec rake ar:create ar:schema:load > /dev/null;
	echo \"Loading congress members...\"; bundle exec rake congress-forms:clone_git[/tmp] > /dev/null;" "$1"
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
