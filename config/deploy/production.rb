# Simple Role Syntax
# ==================
# Supports bulk-adding hosts to roles, the primary server in each group
# is considered to be the first unless any hosts have the primary
# property set.  Don't declare `role :all`, it's a meta role.

set :deploy_to, '/home/ghntfr/github-notifier-production'
set :puma_conf, "#{shared_path}/config/puma.rb"
set :puma_env, "production"
set :sidekiq_require, "#{release_path}/workers/init.rb"
set :sidekiq_env, :production
set :sidekiq_concurrency, 25
set :newrelic_rails_env, 'production'

role :web, %w{ghntfr@web01.githubnotifier.io:91}
role :sidekiq,  %w{ghntfr@web01.githubnotifier.io:91}
