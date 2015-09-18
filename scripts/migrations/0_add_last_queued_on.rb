#!/usr/bin/env ruby

require 'sidekiq'
require 'redis'
require 'newrelic_rpm' # it should be the last entry in the require list

config_file = File.dirname(__FILE__) + '/../../config.yml'
fail "Configuration file " + config_file + " missing!" unless File.exist?(config_file)
CONFIG = YAML.load_file(config_file)

conn = Redis.new(
  :driver => :hiredis,
  :host => CONFIG['redis']['host'],
  :port => CONFIG['redis']['port'],
  :db => CONFIG['redis']['db'],
  network_timeout: 5
)

users_keys = conn.keys("#{CONFIG['redis']['namespace']}:users:*")

users_keys.each do |user_key|
  puts "#{Time.now.strftime("%Y-%m-%dT%l:%M:%S%z")} Execution migration on #{user_key}..."

  last_email_sent_on = conn.hget(user_key, :last_email_sent_on)
  conn.hset(user_key, :last_email_queued_on, last_email_sent_on)
end
