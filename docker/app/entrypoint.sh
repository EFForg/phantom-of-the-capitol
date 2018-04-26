#!/bin/bash
set -e

if [ ! -z "$LOAD_SCHEMA_IF_MISSING" -a "$LOAD_SCHEMA_IF_MISSING" == "true" ]; then
   dbversion="$(rake ar:version)"
   if [ $? -ne 0 ] || grep "Current version: 0" <<<"$dbversion"; then
       echo "Loading schema..."
       bundle exec rake ar:create ar:schema:load > /dev/null
   fi
fi

if [ "$RACK_ENV" != "test" -a "$(echo "$LOAD_CONGRESS" | tr '[:upper:]' '[:lower:]')" = "true" ]; then
    if [ ! -d /datasources/us_congress_members ]; then
        echo "Adding datasource..."
        ./phantom-dc datasource add --git-clone https://github.com/unitedstates/contact-congress.git us_congress /datasources/us_congress_members members/
    fi

    echo "Loading congress members..."
    bundle exec rake phantom-dc:update_git > /dev/null
fi

exec "$@"
