require 'redis'
require 'pp'
require 'yaml'

config_file = File.dirname(__FILE__) + '/../config.yml'
fail "Configuration file " + config_file + " missing!" unless File.exist?(config_file)
CONFIG = YAML.load_file(config_file)

redis = Redis.new(:driver => :hiredis, :host => CONFIG['redis']['host'], :port => CONFIG['redis']['port'], :db => CONFIG['redis']['db'])

obj = {"github_id"=> "",
 "last_event_id"=>"2425257958",
 "followers"=>
  "[\"matteosister\",\"frapontillo\",\"robbixc\",\"alpacaaa\",\"davidefedrigo\",\"rvitaliy\",\"aleinside\",\"thomasvargiu\",\"runcom\",\"anatolinicolae\",\"giordan83\",\"maxcanna\",\"peelandsee\",\"nigrosimone\",\"squaini\",\"riccamastellone\",\"usutest\",\"gitnotifier\"]",
 "registered_on"=>"1416911683",
 "last_email_sent_on"=>"1424189703",
 "last_email_queued_on"=>"1424189703",
 "login"=>"andreausu",
 "token"=>"",
 "email"=>CONFIG['dev_email_address'],
 "notifications_frequency"=>"weekly",
 "disabled_notifications_type" => "[]",
 "email_confirmed" => "1",
 "first_check_completed" => "1"
}

prng = Random.new

redis.pipelined do
  (0..999).each do
    rand_val = prng.rand(1..100000)
    redis.hmset "#{CONFIG['redis']['namespace']}:users:#{rand_val}", :github_id, rand_val, :last_event_id, obj['last_event_id'], :followers, obj['followers'], :registered_on, obj['registered_on'], :last_email_sent_on, obj['last_email_sent_on'], :login, obj['login'], :token, obj['token'], :email, obj['email'], :notifications_frequency, obj['notifications_frequency'], :disabled_notifications_type, obj['disabled_notifications_type'], :email_confirmed, obj['email_confirmed'], :first_check_completed, obj['first_check_completed']
  end
end
