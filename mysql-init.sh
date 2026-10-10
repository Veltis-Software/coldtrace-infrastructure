#!/bin/sh
set -eu
# Restrict interpolation to a simple local-demo password; no SQL string injection.
case "$APP_DB_PASSWORD" in *[!a-zA-Z0-9_-]*|'') echo 'APP_DB_PASSWORD must contain only letters, digits, _ or - for local bootstrap' >&2; exit 1;; esac
export MYSQL_PWD="$MYSQL_ROOT_PASSWORD"
for context in identity asset monitoring alert report maintenance ai subscription; do
  mysql -uroot <<SQL
CREATE DATABASE IF NOT EXISTS ct_${context};
CREATE USER IF NOT EXISTS 'ct_${context}'@'%' IDENTIFIED BY '${APP_DB_PASSWORD}';
GRANT ALL PRIVILEGES ON ct_${context}.* TO 'ct_${context}'@'%';
SQL
done
unset MYSQL_PWD
