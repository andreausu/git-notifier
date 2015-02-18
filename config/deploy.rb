# config valid only for current version of Capistrano
lock '3.3.5'

set :application, 'github-notifier'
set :repo_url, 'git@github.com:andreausu/github-notifier.git'

set :branch, ENV["REVISION"] || ENV["BRANCH_NAME"] || ask('the branch or revison to deploy', `git rev-parse --abbrev-ref HEAD`.chomp) unless ARGV[1] && ARGV[1].include?('rollback')
# We need /usr/sbin/service
set :default_env, { path: "/usr/sbin:$PATH" }

# Default value for :linked_files is []
set :linked_files, fetch(:linked_files, []).push('config.yml', 'config/newrelic.yml')

# Default value for linked_dirs is []
set :linked_dirs, fetch(:linked_dirs, []).push('tmp/pids', 'tmp/sockets', 'log', 'vendor/bundle')

# Default value for keep_releases is 5
set :keep_releases, 5

set :puma_role, :web

set :sidekiq_role, :sidekiq
set :sidekiq_queue, %w(notifications_checker send_email send_email_signup email_builder)

namespace :deploy do

  after :updated, :install_gems do
    on roles(:all) do
      execute "cd #{release_path} && bundle install --deployment --without development"
    end
  end

  after :updated, :install_assets do
    on roles(:web) do
      execute "cd #{release_path} && bower install"
    end
  end

  after :install_assets, :write_deploy_id do
    on roles(:web) do
      execute "cd #{shared_path} && perl -pi -w -e 's/deploy_id:\\s\\w+/deploy_id: #{release_timestamp}/g;' config.yml"
    end
  end

  after :restart, :'puma:phased-restart'
  after :'deploy:updated', :'newrelic:notice_deployment'

end
