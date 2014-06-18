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

su -c "sudo apt-get update; sudo apt-get -y install $DEPENDENCIES" "$1"

mysql -u root -p"$mysql_root" -e "create database if not exists congress_forms_development;  GRANT ALL PRIVILEGES ON congress_forms_development.* TO 'congress_forms'@'localhost' IDENTIFIED BY '$mysql_congress_forms';"
mysql -u root -p"$mysql_root" -e "create database if not exists congress_forms_test;  GRANT ALL PRIVILEGES ON congress_forms_test.* TO 'congress_forms'@'localhost';"

cd /vagrant
cp -a config/database-example.rb config/database.rb
cp -a config/congress-forms_config.rb.example config/congress-forms_config.rb

sed -i "s@^  :password.*@  :password => '$mysql_congress_forms',@" config/database.rb

# Doing this to make sure vagrant doesn't install RVM and Ruby as root; there's probably a cleaner way
su -c "curl -sSL https://get.rvm.io | bash -s stable; source /home/$1/.rvm/scripts/rvm; rvm install ruby-2.1.0; 
rvm gemset create congress-forms; rvm alias create congress-forms ruby-2.1.0@congress-forms; 
bundle install --path /home/$1/.rvm/gems/ruby-2.1.0@congress-forms/gems/; 
echo \"Loading schema...\"; bundle exec rake ar:create ar:schema:load > /dev/null; 
echo \"Loading congress members...\"; bundle exec rake congress-forms:clone_git > /dev/null;" "$1"

echo "Setting up PhantomJS..."
cd /home/$1/
curl -Lo phantomjs.tar.bz2 https://bitbucket.org/ariya/phantomjs/downloads/phantomjs-1.9.7-linux-x86_64.tar.bz2
tar -jxvf phantomjs.tar.bz2 > /dev/null

sudo ln -s /home/$1/phantomjs-1.9.7-linux-x86_64/bin/phantomjs /usr/bin/phantomjs
sudo chmod go-w /vagrant

echo -e "\n\nYou're all done!  Now type 'vagrant ssh', cd into /vagrant, and type 'bundle exec rackup' to run!"
