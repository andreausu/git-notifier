# encoding: utf-8

require 'datadog/statsd'

GC::Profiler.enable

config_file = File.dirname(__FILE__) + '/../config.yml'
fail "Configuration file " + config_file + " missing!" unless File.exist?(config_file)
CONFIG = YAML.load_file(config_file)

STATSD = Datadog::Statsd.new(CONFIG['statsd']['host'], CONFIG['statsd']['port'])

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

Sidekiq.configure_server do |config|
  config.redis = ConnectionPool.new(size: 27, &redis_conn)
end

require_relative 'notifications_checker'
require_relative 'email_builder'
require_relative 'send_email'
require 'newrelic-redis'
require 'newrelic_rpm' # it should be the last entry in the require list
