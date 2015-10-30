#!/usr/bin/env ruby

require 'sidekiq'
require 'redis'
require 'pp'
require_relative '../workers/send_email'
require 'newrelic_rpm' # it should be the last entry in the require list

config_file = File.dirname(__FILE__) + '/../config.yml'
fail "Configuration file " + config_file + " missing!" unless File.exist?(config_file)
CONFIG = YAML.load_file(config_file)

redis_conn = proc {
  Redis.new(
    :driver => :hiredis,
    :host => CONFIG['redis']['host'],
    :port => CONFIG['redis']['port'],
    :db => CONFIG['redis']['db'],
    network_timeout: 5
  )
}

Sidekiq.configure_client do |config|
  config.redis = ConnectionPool.new(size: 27, &redis_conn)
end

#Sidekiq::Client.push(
#  'queue' => 'send_email_signup',
#  'class' => SendEmail,
#  'args' => ['andreausu@gmail.com', "Confirm your Git Notifier email!", 'html', 'confirm', {:confirm_link => 'https://staging.gitnotifier.io/signup/confirm?id=623986&email=andreausu%2Bstaging%40gmail.com&expiry=1454598210&v=953ff69c7ddeaf10aeda12a6eec032a92c21511fb5f87dff1130904cfe0b3143570bd5dfc64062c84fbf1c54995e894d1f51fb126cfd1e3dd916c04ef6b86e35'}]
#)

Sidekiq::Client.push(
  'queue' => 'send_email',
  'class' => SendEmail,
  'args' => [
    'web-OZ7TGr@mail-tester.com',
    "Git Notifier weekly report",
    'html',
    'notification',
    {
      :events =>
        [
          {
            :html => '<a href="https://github.com/usutest">andreausu</a> started following you',
            :text => "1",
            :timestamp => 1423394734,
            :day => "Sunday, February 16"
          },
          {
            :html => '<a href="https://github.com/usutest">antirez</a> forked <a href="https://github.com/usutest">github-notifier</a> to <a href="https://github.com/usutest">antirez/github-notifier</a>',
            :text => "2",
            :timestamp => 1423395934
          },
          {
            :html => '<a href="https://github.com/usutest">meechum</a> starred <a href="https://github.com/usutest">github-notifier</a>',
            :text => "4",
            :timestamp => 1423395934,
            :day => "Sunday, February 15"
          },
          {
            :html => '<a href="https://github.com/usutest">meechum</a> started following you',
            :text => "antirez forked github-notifier to antirez/github-notifier",
            :timestamp => 1423395934
          },
          {
            :html => '<a href="https://github.com/usutest">desmond</a> is not following you anymore',
            :text => "antirez forked github-notifier to antirez/github-notifier",
            :timestamp => 1423395934,
            :day => "Sunday, February 10"
          },
        ],
      :site_url => "https://gitnotifier.io",
      :unsubscribe_url => "https://gitnotifier.io"
    }
  ]
)
