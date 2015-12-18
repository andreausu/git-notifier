#!/usr/bin/env ruby

require 'optparse'
require 'date'
require 'sidekiq'
require 'redis'
require 'pp'
require_relative '../workers/send_email'
require 'newrelic_rpm' # it should be the last entry in the require list

def time_rand from = 0.0, to = Time.now
  Time.at(from + rand * (to.to_f - from.to_f))
end

def inject_day(events)
  previousEvent = nil
  events.map! do |event|
    if previousEvent.nil? || (Time.at(previousEvent[:timestamp]).strftime('%d') != Time.at(event[:timestamp]).strftime('%d'))
      event[:day] = Time.at(event[:timestamp]).strftime('%A, %b %e')
    end
    previousEvent = event
  end

  events
end

config_file = File.dirname(__FILE__) + '/../config.yml'
fail "Configuration file " + config_file + " missing!" unless File.exist?(config_file)
CONFIG = YAML.load_file(config_file)

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: #{$0} [options]"

  opts.on("-n", "--number NUMBER", "Number of events") { |v| options[:events_number] = v }
  opts.on("-m", "--mode MODE", "Notification mode (asap, daily, weekly, confirm, news)") { |v| options[:email_mode] = v }
  opts.on("-t", "--to EMAIL_TO", "Email to") { |v| options[:email_to] = v }
end.parse!

raise 'Missing Email to' if options[:email_to].nil?
raise 'Missing Email mode' if options[:email_mode].nil?

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

case options[:email_mode]
when 'confirm'
  user = 'andreausu'
  link = "https://#{CONFIG['domain']}/signup/confirm?id=999&email=#{CGI.escape(options[:email_to])}&expiry=123456789&v=jwvyewgfuyewgyiwegf"
  Sidekiq::Client.push(
    'queue' => 'send_email_signup',
    'class' => SendEmail,
    'args' => [options[:email_to], 'Confirm your Git Notifier email address!', 'html', 'confirm', {:confirm_link => link, :username => user}]
  )
when 'news', 'newsletter'
  user = 'andreausu'
  unsubscribe_url = URI.escape("https://#{CONFIG['domain']}/unsubscribe?id=9999&expiry=123456789&v=dofhweuhf37365erdvhkbj")

  Sidekiq::Client.push(
    'queue' => 'send_email',
    'class' => SendEmail,
    'args' => [
      options[:email_to],
      "GitHub Notifier changes its name",
      'html',
      'newsletter',
      {
        :content => "Hi #{user},<br /><br />sorry about the extra email, we just wanted to let you know that due to trademark concerns raised by the GitHub legal team we are changing the website name and all its associated entities from GitHub Notifier to Git Notifier.<br /><br />Thank you for using our service!",
        :site_url => "https://#{CONFIG['domain']}",
        :unsubscribe_url => unsubscribe_url
      }
    ]
  )

when 'asap', 'daily', 'weekly'
  raise 'Missing Number of events' if options[:events_number].nil?

  USERNAMES = [
    'antirez',
    'foobar',
    'sceriffowoody',
    'buzz-lightyear',
    'madhatter',
    'alice',
    'dinah',
    'kaiserjacob',
    'mr.broccolo',
    'leoncino',
    'cheshirecat',
    'whiterabbit',
    'labestia',
    'carlo',
    'cesare',
    'unicorno',
    'cose_belle',
    'uolli',
    'ivaaaa',
    'orsetto',
    'gattini',
    'andreausu',
    'bobinsky',
    'ventilatore',
    'slinkydog',
    'starmale1',
    'oreste',
    'biagio',
    'il_tricheco',
    'nonchere',
    'regina-di-cuori',
    'carte',
    'leopoldo',
    'pollo',
    'mr.smith',
    'swagswag',
    'bacca',
    'juvemerda',
    'milano',
    'acmilan',
    'andem',
    'tireminans',
    'sepuminga',
    'bohboh',
    'vitamine',
    'ginocchio',
    'patella',
    'gelenko',
    'sbilenko',
    'sugruuu',
    'amica_copertina'
  ]

  REPOSITORIES = [
    'git-notifier',
    'redis',
    'coreos',
    'etcd',
    'docker',
    'reactjs',
    'coolproject',
    'letsencrypt',
    'ansible',
    'linux',
    'xhyve',
    'flynn',
    'falcor',
    'graphql',
    'influxdb',
    'elasticsearch',
    'gitnotifier-provisioning',
    'CodiceFiscale',
    'vulcand',
    'blog',
    'homebrew',
    'christmas-countdown'
  ]

  ACTIONS = [
    'star',
    'fork',
    'follow',
    'unfollow',
    'deleted'
  ]

  timestamp = Time.now.to_i
  user = 'andreausu' # USERNAMES.sample
  emailEvents = []
  (1..options[:events_number].to_i).each do |n|
    user_action = USERNAMES.sample
    repository = REPOSITORIES.sample
    case ACTIONS.sample
    when 'star'
      html = "<a href=\"https://github.com/#{user_action}\">#{user_action}</a> starred <a href=\"https://github.com/#{user}/#{repository}\">#{repository}</a>"
    when 'fork'
      html = "<a href=\"https://github.com/#{user_action}\">#{user_action}</a> forked <a href=\"https://github.com/#{user}/#{repository}\">#{repository}</a> to <a href=\"https://github.com/#{user_action}\">#{repository}</a>"
    when 'follow'
      html = "<a href=\"https://github.com/#{user_action}\">#{user_action}</a> started following you"
    when 'unfollow'
      html = "<a href=\"https://github.com/#{user_action}\">#{user_action}</a> is not following you anymore"
    when 'deleted'
      html = "#{user_action} that was following you has been deleted"
    end
    timestamp = time_rand(Time.now - 604800) if options[:email_mode] == 'weekly'
    emailEvents << {
      :html => html,
      :text => html.gsub(/<br\s?\/?>/, "\r\n").gsub(/<\/?[^>]*>/, ''),
      :timestamp => timestamp
    }
  end

  inject_day(emailEvents) if options[:email_mode] == 'weekly'

  subject = "You have #{emailEvents.length == 1 ? 'a new notification' : emailEvents.length.to_s + ' new notifications'}"
  notificationsText = subject + (emailEvents.length == 1 ? "!<br />You notification was received on #{Time.at(emailEvents[0][:timestamp]).strftime('%A %b %e')} at #{Time.at(emailEvents[0][:timestamp]).strftime('%k:%M')}." : "!<br />Your last notification was received on #{Time.at(emailEvents[0][:timestamp]).strftime('%A %b %e')} at #{Time.at(emailEvents[0][:timestamp]).strftime('%k:%M')}.")

  case options[:email_mode]
  when 'asap'
    subject = subject
  when 'daily'
    subject = "#{Time.now.strftime('%b %e')} daily report: #{subject}"
  when 'weekly'
    subject = "#{Time.now.strftime('%b %e')} weekly report: #{subject}"
  end

  Sidekiq::Client.push(
    'queue' => 'send_email',
    'class' => SendEmail,
    'args' => [
      options[:email_to],
      subject,
      'html',
      'notification',
      {
        :events => emailEvents,
        :notifications_text => notificationsText,
        :subject => subject,
        :username => user,
        :site_url => "https://gitnotifier.io",
        :unsubscribe_url => "https://gitnotifier.io"
      }
    ]
  )
end
