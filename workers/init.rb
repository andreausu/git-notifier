# encoding: utf-8

GC::Profiler.enable

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
  config.redis = ConnectionPool.new(size: 25, &redis_conn)
end

Sidekiq.configure_server do |config|
  config.redis = ConnectionPool.new(size: 25, &redis_conn)
end

require_relative 'notifications_checker'
require_relative 'email_builder'
require_relative 'send_email'
require 'newrelic-redis'
require 'newrelic_rpm' # it should be the last entry in the require list
