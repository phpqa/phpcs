#!/usr/bin/env sh
set -e

if [ "$(printf %c "$1")" = '-' ]; then
  set -- /sbin/tini -- php /composer/vendor/bin/phpcs "$@"
elif [ "$1" = "/composer/vendor/bin/phpcs" ]; then
  set -- /sbin/tini -- php "$@"
elif [ "$1" = "phpcs" ]; then
  set -- /sbin/tini -- php /composer/vendor/bin/"$@"
elif [ "$1" = "/composer/vendor/bin/phpcbf" ]; then
  set -- /sbin/tini -- php "$@"
elif [ "$1" = "phpcbf" ]; then
  set -- /sbin/tini -- php /composer/vendor/bin/"$@"
fi

exec "$@"
