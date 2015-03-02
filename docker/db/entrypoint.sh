#!/bin/bash
set -e

if [ "${1:0:1}" = '-' ]; then
	set -- mysqld "$@"
fi

if [ "$1" = 'mysqld' ]; then
	# read DATADIR from the MySQL config
	DATADIR="$("$@" --verbose --help 2>/dev/null | awk '$1 == "datadir" { print $2; exit }')"

	if [ ! -d "$DATADIR/mysql" ]; then
		if [ -z "$MYSQL_ROOT_PASSWORD" -a -z "$MYSQL_ALLOW_EMPTY_PASSWORD" ]; then
			echo >&2 'error: database is uninitialized and MYSQL_ROOT_PASSWORD not set'
			echo >&2 '  Did you forget to add -e MYSQL_ROOT_PASSWORD=... ?'
			exit 1
		fi

		if [ -z "$MYSQL_APP_PASSWORD" ]; then
			echo >&2 'error: database is uninitialized and MYSQL_APP_PASSWORD not set'
			echo >&2 '  Did you forget to add -e MYSQL_APP_PASSWORD=... ?'
			exit 1
		fi

		echo 'Running mysql_install_db ...'
		mysql_install_db --datadir="$DATADIR"
		echo 'Finished mysql_install_db'

		# These statements _must_ be on individual lines, and _must_ end with
		# semicolons (no line breaks or comments are permitted).
		# TODO proper SQL escaping on ALL the things D:

		tempSqlFile='/tmp/mysql-first-time.sql'
		cat > "$tempSqlFile" <<-EOSQL
			DELETE FROM mysql.user ;
			CREATE USER 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}' ;
			GRANT ALL ON *.* TO 'root'@'%' WITH GRANT OPTION ;
			DROP DATABASE IF EXISTS test ;

			CREATE USER 'phantom_dc'@'%' IDENTIFIED BY '${MYSQL_APP_PASSWORD}' ;

			GRANT ALL ON \`phantom_dc_production\`.* TO 'phantom_dc'@'%' ;
			GRANT ALL ON \`phantom_dc_development\`.* TO 'phantom_dc'@'%' ;
			GRANT ALL ON \`phantom_dc_test\`.* TO 'phantom_dc'@'%' ;
		EOSQL

		echo 'FLUSH PRIVILEGES ;' >> "$tempSqlFile"

                echo 'use mysql ;' >> "$tempSqlFile"
                mysql_tzinfo_to_sql /usr/share/zoneinfo | sed 's/Local time zone must be set--see zic manual page/UNSET/g' >> "$tempSqlFile"

		set -- "$@" --init-file="$tempSqlFile"
	fi

	chown -R mysql:mysql "$DATADIR"
fi

exec "$@"
