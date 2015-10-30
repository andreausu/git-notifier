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

users_keys = Sidekiq.redis do |conn|
  conn.keys("#{CONFIG['redis']['namespace']}:users:*")
end

users_keys.each do |user_key|
  puts "#{Time.now.strftime("%Y-%m-%dT%l:%M:%S%z")} Enqueueing #{user_key}..."
  user = Sidekiq.redis { |conn| conn.hgetall(user_key) }
  email = user['email']
  next if user['email_confirmed'] == 0 || user['disabled_notifications_type'].include?('site-news') # The user doesn't want to receive newsletters

  expiry = (Time.now + 31536000).to_i.to_s

  digest = OpenSSL::Digest.new('sha512')
  hmac = OpenSSL::HMAC.hexdigest(digest, CONFIG['secret'], user['github_id'] + expiry)

  unsubscribe_url = URI.escape("https://#{CONFIG['domain']}/unsubscribe?id=#{user['github_id']}&expiry=#{expiry}&v=#{hmac}")

  Sidekiq::Client.push(
    'queue' => 'send_email',
    'class' => SendEmail,
    'args' => [
      email,
      "GitHub Notifier changes its name",
      'html',
      'newsletter',
      {
        :content => "Hi #{user['login']},<br /><br />sorry about the extra email, we just wanted to let you know that due to trademark concerns raised by the GitHub legal team we are changing the website name and all its associated entities from GitHub Notifier to Git Notifier.<br /><br />Thank you for using our service!",
        :site_url => "https://#{CONFIG['domain']}",
        :unsubscribe_url => unsubscribe_url
      }
    ]
  )

end
