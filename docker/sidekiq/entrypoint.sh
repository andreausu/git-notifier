#!/bin/bash
set -e

cd /usr/src/app
cp config.yml.example config.yml

if [ "$APP_NEWRELIC_API_KEY" ]; then
  cp config/newrelic.example.yml config/newrelic.yml
  sed -i 's/APP_NEWRELIC_API_KEY/'"$APP_NEWRELIC_API_KEY"'/g' /usr/src/app/config/newrelic.yml
fi

sed -i 's/APP_CONFIG_GITHUB_CLIENT_ID/'"$APP_CONFIG_GITHUB_CLIENT_ID"'/g' /usr/src/app/config.yml
sed -i 's/APP_CONFIG_GITHUB_CLIENT_SECRET/'"$APP_CONFIG_GITHUB_CLIENT_SECRET"'/g' /usr/src/app/config.yml

sed -i 's/APP_CONFIG_REDIS_HOST/'"$APP_CONFIG_REDIS_HOST"'/g' /usr/src/app/config.yml
sed -i 's/APP_CONFIG_REDIS_PORT/'"$APP_CONFIG_REDIS_PORT"'/g' /usr/src/app/config.yml
sed -i 's/APP_CONFIG_REDIS_DB/'"$APP_CONFIG_REDIS_DB"'/g' /usr/src/app/config.yml
sed -i 's/APP_CONFIG_REDIS_NAMESPACE/'"$APP_CONFIG_REDIS_NAMESPACE"'/g' /usr/src/app/config.yml

sed -i 's/APP_CONFIG_DOMAIN/'"$APP_CONFIG_DOMAIN"'/g' /usr/src/app/config.yml

sed -i 's/APP_CONFIG_SECRET/'"$APP_CONFIG_SECRET"'/g' /usr/src/app/config.yml

sed -i 's/APP_CONFIG_MAIL_ENABLE/'"$APP_CONFIG_MAIL_ENABLE"'/g' /usr/src/app/config.yml
sed -i 's/APP_CONFIG_MAIL_METHOD/'"$APP_CONFIG_MAIL_METHOD"'/g' /usr/src/app/config.yml
sed -i 's/APP_CONFIG_MAIL_FROM/'"$APP_CONFIG_MAIL_FROM"'/g' /usr/src/app/config.yml
sed -i 's/APP_CONFIG_MAIL_HOST/'"$APP_CONFIG_MAIL_HOST"'/g' /usr/src/app/config.yml
sed -i 's/APP_CONFIG_MAIL_PORT/'"$APP_CONFIG_MAIL_PORT"'/g' /usr/src/app/config.yml
sed -i 's/APP_CONFIG_MAIL_USER/'"$APP_CONFIG_MAIL_USER"'/g' /usr/src/app/config.yml
sed -i 's/APP_CONFIG_MAIL_PASSWORD/'"$APP_CONFIG_MAIL_PASSWORD"'/g' /usr/src/app/config.yml
sed -i 's/APP_CONFIG_MAIL_SSL/'"$APP_CONFIG_MAIL_SSL"'/g' /usr/src/app/config.yml

sed -i 's/APP_CONFIG_DEPLOY_ID/'"$APP_CONFIG_DEPLOY_ID"'/g' /usr/src/app/config.yml

sed -i 's/APP_CONFIG_EMAIL_DEV_ON_SIGNUP/'"$APP_CONFIG_EMAIL_DEV_ON_SIGNUP"'/g' /usr/src/app/config.yml
sed -i 's/APP_CONFIG_DEV_EMAIL_ADDRESS/'"$APP_CONFIG_DEV_EMAIL_ADDRESS"'/g' /usr/src/app/config.yml

bundle exec sidekiq -e "$APP_ENV" -r ./workers/init.rb -q notifications_checker -q send_email -q send_email_signup -q email_builder
