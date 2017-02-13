FROM gitnotifier/ruby:2.4.0

# Set proper locale
ENV APP_ENV=development \
APP_CONFIG_GITHUB_CLIENT_ID=someid \
APP_CONFIG_GITHUB_CLIENT_SECRET=somesecret \

APP_CONFIG_REDIS_HOST=localhost \
APP_CONFIG_REDIS_PORT=6379 \
APP_CONFIG_REDIS_DB=1 \
APP_CONFIG_REDIS_NAMESPACE=ghntfr \

APP_CONFIG_STATSD_HOST=localhost \
APP_CONFIG_STATSD_PORT=8125 \

APP_CONFIG_DOMAIN=gitnotifier.local \

APP_CONFIG_SECRET=somesecret \

APP_CONFIG_MAIL_ENABLE=true \
APP_CONFIG_MAIL_METHOD=smtp \
APP_CONFIG_MAIL_FROM="Git Notifier <sender@email.com>" \
APP_CONFIG_MAIL_HOST=smtp.example.org \
APP_CONFIG_MAIL_PORT=587 \
APP_CONFIG_MAIL_USER=someuser@somedomain.com \
APP_CONFIG_MAIL_PASSWORD=somepass \

APP_CONFIG_DEPLOY_ID=1 \

APP_CONFIG_EMAIL_DEV_ON_SIGNUP=false \
APP_CONFIG_DEV_EMAIL_ADDRESS=some@email.com

ENTRYPOINT [ "/usr/src/app/docker/sidekiq/entrypoint.sh" ]
