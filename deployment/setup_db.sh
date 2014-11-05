#!/usr/bin/env bash

# $1 = user to run scripts as

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

apt-get update
apt-get -y install mysql-server 

mysql -u root -p"$mysql_root" -e "create database if not exists congress_forms_development;  GRANT ALL PRIVILEGES ON congress_forms_development.* TO 'congress_forms'@'localhost';"
mysql -u root -p"$mysql_root" -e "create database if not exists congress_forms_test;  GRANT ALL PRIVILEGES ON congress_forms_test.* TO 'congress_forms'@'localhost';"
su -c "source /home/$1/.rvm/scripts/rvm; rvm use ruby-2.1.0;
gem install bundler -v 1.5.1;
rvm gemset create congress-forms; rvm alias create congress-forms ruby-2.1.0@congress-forms; 
bundle install --path /home/$1/.rvm/gems/ruby-2.1.0@congress-forms/gems/; 
echo \"Loading schema...\"; bundle exec rake ar:create ar:schema:load > /dev/null;
echo \"Loading congress members...\"; bundle exec rake congress-forms:clone_git[/tmp] > /dev/null;" "$1"
