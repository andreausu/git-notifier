require 'redis'
require 'pp'
require 'yaml'

config_file = File.dirname(__FILE__) + '/../config.yml'
fail "Configuration file " + config_file + " missing!" unless File.exist?(config_file)
CONFIG = YAML.load_file(config_file)

redis = Redis.new(:driver => :hiredis, :host => CONFIG['redis']['host'], :port => CONFIG['redis']['port'], :db => CONFIG['redis']['db'])

token = ARGV[0] if ARGV[0]

raise 'No token specified' unless token && token.length == 40

user_id = redis.get "#{CONFIG['redis']['namespace']}:tokens:#{token}"

raise 'Token not found' unless user_id

keys_to_delete = redis.keys "#{CONFIG['redis']['namespace']}:*:#{user_id}"
keys_to_delete << "#{CONFIG['redis']['namespace']}:tokens:#{token}"

redis.multi do
  keys_to_delete.each do |k|
    puts "Deleting #{k}..."
    redis.del k
  end
end
