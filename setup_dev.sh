#!/usr/bin/env bash

# stop setup script if any command fails
set -e

DEPENDENCIES="mysql-server curl imagemagick libmysql++-dev libpq-dev git libqt4-dev xvfb gnupg2"

random() {
    head -c $1 /dev/urandom | base64
}

mysql_root=$(random 20)
mysql_congress_forms=$(random 20)
sudo debconf-set-selections <<EOF
mysql-server-5.5 mysql-server/root_password password $mysql_root
mysql-server-5.5 mysql-server/root_password_again password $mysql_root
EOF

apt-get update
apt-get -y install $DEPENDENCIES

mysql -u root -p"$mysql_root" -e "create database if not exists congress_forms_development;  GRANT ALL PRIVILEGES ON congress_forms_development.* TO 'congress_forms'@'localhost' IDENTIFIED BY '$mysql_congress_forms';"
mysql -u root -p"$mysql_root" -e "create database if not exists congress_forms_test;  GRANT ALL PRIVILEGES ON congress_forms_test.* TO 'congress_forms'@'localhost';"

cd /vagrant

cp -a config/database-example.rb config/database.rb
cp -a config/congress-forms_config.rb.example config/congress-forms_config.rb

sed -i "s@^  :password.*@  :password => '$mysql_congress_forms',@" config/database.rb

HOME=/home/vagrant sudo -u vagrant /bin/bash <<EOF
echo "Setting up RVM and Ruby..."
cd /tmp
curl -O https://sks-keyservers.net/sks-keyservers.netCA.pem
gpg2 --keyserver hkps://hkps.pool.sks-keyservers.net --keyserver-options ca-cert-file=sks-keyservers.netCA.pem --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3
curl -O https://raw.githubusercontent.com/wayneeseguin/rvm/master/binscripts/rvm-installer
curl -O https://raw.githubusercontent.com/wayneeseguin/rvm/master/binscripts/rvm-installer.asc
gpg2 --verify rvm-installer.asc &&
bash rvm-installer stable
source /home/vagrant/.rvm/scripts/rvm
rvm install ruby-2.1.0

cd /vagrant
gem install json -v '1.8.2'
gem install nokogiri -v '1.6.6.2'
bundle install

echo "Loading schema..."
bundle exec rake ar:create ar:schema:load > /dev/null
RACK_ENV=test bundle exec rake ar:create ar:schema:load > /dev/null
echo "Loading congress members..."
bundle exec rake congress-forms:clone_git[/home/vagrant] > /dev/null

echo "Setting up PhantomJS..."
cd /home/vagrant
curl -Lo phantomjs.tar.bz2 https://bitbucket.org/ariya/phantomjs/downloads/phantomjs-1.9.8-linux-x86_64.tar.bz2
tar -jxvf phantomjs.tar.bz2 > /dev/null
EOF

ln -s /home/vagrant/phantomjs-1.9.8-linux-x86_64/bin/phantomjs /usr/bin/phantomjs

echo -e "\n\nYou're all done!  Now type 'vagrant ssh', cd into /vagrant, and type 'rackup --host=0.0.0.0' to run!"
