FROM nginx

ENV APP_CONFIG_DOMAIN=gitnotifier.local \
APP_UPSTREAM_PUMA=localhost

ADD ./docker/nginx/nginx.conf /etc/nginx/nginx.conf
ADD ./docker/nginx/gitnotifier /etc/nginx/conf.d/gitnotifier

ADD ./docker/nginx/entrypoint.sh /entrypoint.sh

ADD . /var/www/github-notifier/current

ENTRYPOINT ["/entrypoint.sh"]
