#!/bin/sh
set -e

if [ "${1:0:1}" = "-" ]; then
  set -- /sbin/tini -- php /vendor/bin/phpcs "$@"
elif [ "$1" = "/vendor/bin/phpcs" ]; then
  set -- /sbin/tini -- php "$@"
elif [ "$1" = "phpcs" ]; then
  set -- /sbin/tini -- php /vendor/bin/"$@"
elif [ "$1" = "/vendor/bin/phpcbf" ]; then
  set -- /sbin/tini -- php "$@"
elif [ "$1" = "phpcbf" ]; then
  set -- /sbin/tini -- php /vendor/bin/"$@"
fi

exec "$@"
