GC::Profiler.enable

require 'sinatra/base'
require "sinatra/reloader"
require 'rack/csrf'
require 'rack-flash'
require 'yaml'
require 'redis'
require 'sidekiq'
require_relative 'workers/notifications_checker'
require_relative 'workers/send_email'
require_relative 'app.rb'
require 'newrelic-redis'
require 'newrelic_rpm' # it should be the last entry in the require list

run GitNotifier
