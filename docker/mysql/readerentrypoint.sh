#!/bin/bash
set -eo pipefail
shopt -s nullglob

. /entrypoint.sh

# pasted from https://github.com/docker-library/mysql/blob/master/8.0/docker-entrypoint.sh
_main() {
	# if command starts with an option, prepend mysqld
	if [ "${1:0:1}" = '-' ]; then
		set -- mysqld "$@"
	fi

	# skip setup if they aren't running mysqld or want an option that stops mysqld
	if [ "$1" = 'mysqld' ] && ! _mysql_want_help "$@"; then
		mysql_note "Entrypoint script for MySQL Server ${MYSQL_VERSION} started."

		mysql_check_config "$@"
		# Load various environment variables
		docker_setup_env "$@"
		docker_create_db_directories

		# If container is started as root user, restart as dedicated mysql user
		if [ "$(id -u)" = "0" ]; then
			mysql_note "Switching to dedicated user 'mysql'"
			exec gosu mysql "$BASH_SOURCE" "$@"
		fi

		# there's no database, so it needs to be initialized
		if [ -z "$DATABASE_ALREADY_EXISTS" ]; then
			docker_verify_minimum_env

			# check dir permissions to reduce likelihood of half-initialized database
			ls /docker-entrypoint-initdb.d/ > /dev/null

			docker_init_database_dir "$@"

			mysql_note "Starting temporary server"
			docker_temp_server_start "$@" --skip-log-bin  --log-slave-updates=OFF --skip-slave-preserve-commit-order
			mysql_note "Temporary server started."
			docker_setup_db
			docker_process_init_files /docker-entrypoint-initdb.d/*

			mysql_expire_root_user

			mysql_note "Stopping temporary server"
			docker_temp_server_stop
			mysql_note "Temporary server stopped"

			echo
			mysql_note "MySQL init process done. Ready for start up."
			echo
		fi
	fi
	"$@" --daemonize 
    for f in /docker-entrypoint-bootstrap.d/*.sql; do
        [ -f "$f" ] || continue
        mysql_note "$0: running $f"; docker_process_sql < "$f"; echo
    done
	sleep 1
	mysql_note "$0: starting binlog reader"
	touch /tmp/binlogreader.log
	proxysql_binlog_reader -h 127.0.0.1 -u root -p "$MYSQL_ROOT_PASSWORD" -P 3306 -l 6020 -L /tmp/binlogreader.log
	sleep 1
	tail -f /tmp/binlogreader.log

#    for i in {30..0}; do
#        if [[ $(proxysql_binlog_reader -h 127.0.0.1 -u root -p "$MYSQL_ROOT_PASSWORD" -P 3306 -l 6020 -L /tmp/binlogreader.log 2>&1 >/dev/null) == *"already running"* ]]; then   
#            mysql_note "$0: reader is running!"
#            break
#        fi
#        mysql_note "$0: still not ready?"
#        sleep 1
#    done
}

# If we are sourced from elsewhere, don't perform any further actions
if ! _is_sourced; then
	_main "$@"
fi