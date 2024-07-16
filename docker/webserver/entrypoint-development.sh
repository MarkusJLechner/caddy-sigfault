#!/bin/bash

echo "run development entrypoint..."

if [ ! -f "/var/www/web/.env" ]; then
    echo "######################################################################################"
    echo ""
    echo "    .env is missing!"
    echo ""
    echo "######################################################################################"
fi

if [ ! -d "/var/www/web/vendor" ]; then
    echo "######################################################################################"
    echo ""
    echo "    vendor folder missing, composer install"
    echo ""
    echo "######################################################################################"

    rm "/var/www/web/.composerHash"
fi

echo "+++ Remove bootstrap cache"
rm -rf bootstrap/cache/*.php

# wait for mysql service healthy
while ! wget  -q --spider mysql:3306; do
    echo "wait for db connection..."
    sleep 3
done

# Sometimes vite does not delete temporary "hot" file (HMR). This is a workaround to always delete it
rm public/hot

exec "$@"
