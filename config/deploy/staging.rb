# Simple Role Syntax
# ==================
# Supports bulk-adding hosts to roles, the primary server in each group
# is considered to be the first unless any hosts have the primary
# property set.  Don't declare `role :all`, it's a meta role.

# Default deploy_to directory is /var/www/my_app_name
set :deploy_to, '/home/ghntfr/github-notifier-staging'
set :puma_conf, "#{release_path}/config/puma.rb"
set :puma_env, "staging"
set :sidekiq_require, "#{release_path}/workers/init.rb"
set :sidekiq_env, :staging
set :sidekiq_concurrency, 2
set :newrelic_rails_env, 'staging'

role :web, %w{ghntfr@web01.usu.li:91}
role :sidekiq,  %w{ghntfr@web01.usu.li:91}
