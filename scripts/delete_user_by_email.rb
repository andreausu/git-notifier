require 'redis'
require 'pp'
require 'yaml'

config_file = File.dirname(__FILE__) + '/../config.yml'
fail "Configuration file " + config_file + " missing!" unless File.exist?(config_file)
CONFIG = YAML.load_file(config_file)

redis = Redis.new(:driver => :hiredis, :host => CONFIG['redis']['host'], :port => CONFIG['redis']['port'], :db => CONFIG['redis']['db'])

email_to_delete = ARGV[0] if ARGV[0]

raise 'No email specified' unless email_to_delete

keys_to_delete = []
users_keys = redis.keys("#{CONFIG['redis']['namespace']}:users:*")

users_keys.each do |user_key|
  email = redis.hget(user_key, :email)
  if email == email_to_delete
    user_id = redis.hget(user_key, :github_id)
    token = redis.hget(user_key, :token)
    keys_to_delete = redis.keys "#{CONFIG['redis']['namespace']}:*:#{user_id}"
    keys_to_delete << "#{CONFIG['redis']['namespace']}:tokens:#{token}"
  end
end

redis.multi do
  keys_to_delete.each do |k|
    puts "Deleting #{k}..."
    redis.del k
  end
end
