#!/usr/bin/env ruby

require 'sidekiq'
require 'redis'
require_relative '../workers/notifications_checker'
require_relative '../workers/email_builder'
require 'newrelic_rpm' # it should be the last entry in the require list

config_file = File.dirname(__FILE__) + '/../config.yml'
fail "Configuration file " + config_file + " missing!" unless File.exist?(config_file)
CONFIG = YAML.load_file(config_file)

users_keys = nil

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

Sidekiq.redis do |conn|
  users_keys = conn.keys("#{CONFIG['redis']['namespace']}:users:*")
end

jobs_args = []

users_keys.each do |user_key|
  puts "#{Time.now.strftime("%Y-%m-%dT%l:%M:%S%z")} Enqueueing #{user_key}..."
  jobs_args << [user_key]
end

Sidekiq::Client.push_bulk('queue' => 'notifications_checker', 'class' => NotificationsChecker, 'args' => jobs_args)


cmds = []
jobs_args = []
events_lists_keys = nil
Sidekiq.redis do |conn|
  events_lists_keys = conn.keys("#{CONFIG['redis']['namespace']}:events:batch:*")
  conn.pipelined do
    events_lists_keys.each do |events_list_key|
      cmds << { future: conn.hgetall("#{CONFIG['redis']['namespace']}:users:" + events_list_key.split(':').last), object: events_list_key }
    end
  end
end

cmds.each do |c|
  while c[:future].value.is_a?(Redis::FutureNotReady)
    sleep(1.0 / 100.0)
  end

  user = c[:future].value
  events_list_key = c[:object]

  new_key = "#{CONFIG['redis']['namespace']}:processing:events:batch:" + events_list_key.split(':').last

  next if user['email_confirmed'] == "0"

  case user['notifications_frequency']
  when 'asap'
    jobs_args << [new_key]
    puts "#{Time.now.strftime("%Y-%m-%dT%l:%M:%S%z")} EmailBuilder job enqueued"
  when 'daily'
    if user['last_email_sent_on'].to_i <= (Time.now.to_i - (60 * 60 * 24)) # 1 day
      jobs_args << [new_key]
      puts "#{Time.now.strftime("%Y-%m-%dT%l:%M:%S%z")} EmailBuilder job enqueued"
    else
      puts "#{Time.now.strftime("%Y-%m-%dT%l:%M:%S%z")} Waiting for some more time before enqueuing the EmailBuilder job"
    end
  when 'weekly'
    if user['last_email_sent_on'] <= (Time.now.to_i - (60 * 60 * 24 * 7)) # 7 days
      jobs_args << [new_key]
      puts "#{Time.now.strftime("%Y-%m-%dT%l:%M:%S%z")} EmailBuilder job enqueued"
    else
      puts "#{Time.now.strftime("%Y-%m-%dT%l:%M:%S%z")} Waiting for some more time before enqueuing the EmailBuilder job"
    end
  end

end

Sidekiq.redis do |conn|
  conn.multi do
    jobs_args.each do |events_list_key|
      conn.rename("#{CONFIG['redis']['namespace']}:events:batch:" + events_list_key[0].split(':').last, events_list_key[0])
    end
    Sidekiq::Client.push_bulk('queue' => 'email_builder', 'class' => EmailBuilder, 'args' => jobs_args)
  end
end
