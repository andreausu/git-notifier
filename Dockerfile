FROM ruby:2.4.0-slim

# Set proper locale
ENV LANG=C.UTF-8

# throw errors if Gemfile has been modified since Gemfile.lock
RUN bundle config --global frozen 1 && \
buildDeps=' \
		make \
		gcc \
		patch \
	' && \
  apt-get update && apt-get install -y --no-install-recommends $buildDeps && \
  rm -rf /var/lib/apt/lists/*

ONBUILD ADD . /usr/src/app
ONBUILD WORKDIR /usr/src/app
ONBUILD RUN bundle install
