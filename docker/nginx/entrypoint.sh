#!/bin/bash
set -e

sed -i 's/APP_CONFIG_DOMAIN/'"$APP_CONFIG_DOMAIN"'/g' /etc/nginx/conf.d/gitnotifier

sed -i 's/APP_UPSTREAM_PUMA/'"$APP_UPSTREAM_PUMA"'/g' /etc/nginx/conf.d/gitnotifier

nginx -c /etc/nginx/nginx.conf
