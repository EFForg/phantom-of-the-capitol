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

if [ $1 = "vagrant" ]; then
  apt-get update
  apt-get -y install $DEPENDENCIES
else
  sudo apt-get update
  sudo apt-get -y install $DEPENDENCIES
fi

mysql -u root -p"$mysql_root" -e "create database if not exists congress_forms_development;  GRANT ALL PRIVILEGES ON congress_forms_development.* TO 'congress_forms'@'localhost' IDENTIFIED BY '$mysql_congress_forms';"
mysql -u root -p"$mysql_root" -e "create database if not exists congress_forms_test;  GRANT ALL PRIVILEGES ON congress_forms_test.* TO 'congress_forms'@'localhost';"

cd /$1
cp -a config/database-example.rb config/database.rb
cp -a config/congress-forms_config.rb.example config/congress-forms_config.rb

sed -i "s@^  :password.*@  :password => '$mysql_congress_forms',@" config/database.rb

HOME=/home/$1 sudo -u $1 /bin/bash <<EOF
echo "Setting up RVM and Ruby..."
curl -sSL https://get.rvm.io | bash -s stable
source /home/$1/.rvm/scripts/rvm
rvm install ruby-2.1.0

cd .
if [ $1 = "vagrant" ]; then
  gem install json -v '1.8.1'
  sudo bundle install
  echo "Loading schema..."
  sudo bundle exec rake ar:create ar:schema:load > /dev/null
  echo "Loading congress members..."
  sudo bundle exec rake congress-forms:clone_git > /dev/null
else
  rvm gemset create congress-forms
  rvm alias create congress-forms ruby-2.1.0@congress-forms
  bundle install --path $HOME/.rvm/gems/ruby-2.1.0@congress-forms/gems/
  echo "Loading schema..."
  bundle exec rake ar:create ar:schema:load > /dev/null
  echo "Loading congress members..."
  bundle exec rake congress-forms:clone_git > /dev/null
fi

echo "Setting up PhantomJS..."
cd /home/$1
curl -Lo phantomjs.tar.bz2 https://bitbucket.org/ariya/phantomjs/downloads/phantomjs-1.9.7-linux-x86_64.tar.bz2
tar -jxvf phantomjs.tar.bz2 > /dev/null
EOF

sudo ln -s /home/$1/phantomjs-1.9.7-linux-x86_64/bin/phantomjs /usr/bin/phantomjs
sudo chmod go-w /$1

echo -e "\n\nYou're all done!  Now type 'vagrant ssh', cd into /vagrant, and type 'sudo bundle exec rackup' to run!"
