#!/usr/bin/env bash

# stop setup script if any command fails
set -e

DEPENDENCIES="mysql-server curl imagemagick libmysql++-dev libpq-dev git libqt4-dev xvfb"

random() {
    head -c $1 /dev/urandom | base64
}

mysql_root=$(random 20)
mysql_congress_forms=$(random 20)
sudo debconf-set-selections <<EOF
mysql-server-5.5 mysql-server/root_password password $mysql_root
mysql-server-5.5 mysql-server/root_password_again password $mysql_root
EOF

sudo apt-get update
sudo apt-get -y install $DEPENDENCIES

mysql -u root -p"$mysql_root" -e "create database if not exists congress_forms_development;  GRANT ALL PRIVILEGES ON congress_forms_development.* TO 'congress_forms'@'localhost' IDENTIFIED BY '$mysql_congress_forms';"
mysql -u root -p"$mysql_root" -e "create database if not exists congress_forms_test;  GRANT ALL PRIVILEGES ON congress_forms_test.* TO 'congress_forms'@'localhost';"

cd /congress-forms

cp -a config/database-example.rb config/database.rb
cp -a config/congress-forms_config.rb.example config/congress-forms_config.rb

sed -i "s@^  :password.*@  :password => '$mysql_congress_forms',@" config/database.rb

HOME=/home/ubuntu /bin/bash <<EOF
echo "Setting up RVM and Ruby..."
curl -sSL https://get.rvm.io | bash -s stable
source /home/ubuntu/.rvm/scripts/rvm
rvm install ruby-2.1.0

cd .
bundle install

echo "Loading schema..."
bundle exec rake ar:create ar:schema:load > /dev/null
echo "Loading congress members..."
bundle exec rake congress-forms:clone_git > /dev/null

echo "Setting up PhantomJS..."
cd /home/ubuntu
curl -Lo phantomjs.tar.bz2 https://bitbucket.org/ariya/phantomjs/downloads/phantomjs-1.9.7-linux-x86_64.tar.bz2
tar -jxvf phantomjs.tar.bz2 > /dev/null
EOF

sudo ln -s /home/ubuntu/phantomjs-1.9.7-linux-x86_64/bin/phantomjs /usr/bin/phantomjs
sudo chmod go-w /congress-forms

echo "Setup Complete"
