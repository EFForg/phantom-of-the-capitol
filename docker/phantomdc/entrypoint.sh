#!/bin/bash
set -e

if [ ! -d "/var/lib/mysql/phantom_dc_$RACK_ENV" ]; then
	echo "Loading schema..."
	bash -l -c 'bundle exec rake ar:create ar:schema:load' > /dev/null
	if [ "$RACK_ENV" != "test" ]; then
		echo "Loading congress members..."
		bash -l -c 'bundle exec rake phantom-dc:update_git[/home/phantomdc/contact-congress]' > /dev/null
	fi
fi

exec "$@"
