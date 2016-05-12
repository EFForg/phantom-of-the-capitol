#!/bin/bash
set -e

if [ ! -d "/var/lib/mysql/phantom_dc_$RACK_ENV" -a `padrino r "puts ActiveRecord::Base.configurations[Padrino.env][:host] == ENV['DB_PORT_3306_TCP_ADDR'] && ActiveRecord::Base.configurations[Padrino.env][:password] == ENV['DB_ENV_MYSQL_APP_PASSWORD']"` == true ]; then
	echo "Loading schema..."
	bundle exec rake ar:create ar:schema:load > /dev/null
	if [ "$RACK_ENV" != "test" -a "$(echo "$LOAD_CONGRESS" | tr '[:upper:]' '[:lower:]')" = "true" ]; then
                ./phantom-dc datasource add --git-clone https://github.com/unitedstates/contact-congress.git us_congress /datasources/us_congress members/
		echo "Loading congress members..."
		bundle exec rake phantom-dc:update_git > /dev/null
	fi
fi

exec "$@"
