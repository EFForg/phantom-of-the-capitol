#!/usr/bin/env bash

# stop setup script if any command fails
set -e

DEPENDENCIES="mysql-server curl imagemagick libmysql++-dev libpq-dev git libqt4-dev xvfb gnupg2"

random() {
    head -c $1 /dev/urandom | base64
}

mysql_root=$(random 20)
mysql_phantom_dc=$(random 20)
sudo debconf-set-selections <<EOF
mysql-server-5.5 mysql-server/root_password password $mysql_root
mysql-server-5.5 mysql-server/root_password_again password $mysql_root
EOF

apt-get update
apt-get -y install $DEPENDENCIES

mysql -u root -p"$mysql_root" -e "create database if not exists phantom_dc_development;  GRANT ALL PRIVILEGES ON phantom_dc_development.* TO 'phantom_dc'@'localhost' IDENTIFIED BY '$mysql_phantom_dc';"
mysql -u root -p"$mysql_root" -e "create database if not exists phantom_dc_test;  GRANT ALL PRIVILEGES ON phantom_dc_test.* TO 'phantom_dc'@'localhost';"
mysql_tzinfo_to_sql /usr/share/zoneinfo | mysql -u root mysql -p"$mysql_root"

cd /vagrant

cp -a config/database.rb.example config/database.rb
cp -a config/phantom-dc_config.rb.example config/phantom-dc_config.rb

sed -i "s@^  :password.*@  :password => '$mysql_phantom_dc',@" config/database.rb

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
rvm install ruby-2.2.0

cd /vagrant
gem install bundler
gem install json -v '1.8.2'
gem install nokogiri -v '1.6.6.2'
bundle install
echo 'cd /vagrant' >> ~/.bashrc

echo "Loading schema..."
bundle exec rake ar:create ar:schema:load > /dev/null
RACK_ENV=test bundle exec rake ar:create ar:schema:load > /dev/null
echo "Loading congress members..."
bundle exec rake phantom-dc:clone_git[/home/vagrant] > /dev/null

echo "Setting up PhantomJS..."
cd /home/vagrant
curl -Lo phantomjs.tar.bz2 https://bitbucket.org/ariya/phantomjs/downloads/phantomjs-1.9.8-linux-x86_64.tar.bz2
tar -jxvf phantomjs.tar.bz2 > /dev/null
EOF

ln -s /home/vagrant/phantomjs-1.9.8-linux-x86_64/bin/phantomjs /usr/bin/phantomjs

echo -e "\n\nYou're all done!  Now type 'vagrant ssh', cd into /vagrant, and type 'rackup --host=0.0.0.0' to run!"
