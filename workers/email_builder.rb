require 'openssl'
require 'pp'
require 'uri'
require_relative 'send_email'

class EmailBuilder
  include Sidekiq::Worker
  sidekiq_options :queue => :email_builder
  def perform(events_list_key)

    events = nil
    user = nil
    emailEvents = []
    event_ids = []

    Sidekiq.redis do |conn|
      conn.pipelined do
        events = conn.lrange(events_list_key, 0, '-1')
        user = conn.hgetall("#{CONFIG['redis']['namespace']}:users:" + events_list_key.split(':').last)
      end
    end

    events.each do |event|
      event = JSON.parse(event)
      type = event['type']
      entity = event['entity']
      event_name = ''

      next if user['disabled_notifications_type'] && user['disabled_notifications_type'].include?(type)

      timestamp = Time.now.to_i
      timestamp_at_midnight = (timestamp - timestamp % (3600*24)).to_s

      if entity['id']
        if type == 'follow' || type == 'unfollow'
          timestamp = Time.now.to_i
          event_name = "#{entity['id']}_#{type}_#{timestamp_at_midnight}"
        else
          event_name = "#{entity['id']}_#{timestamp_at_midnight}"
        end
      else
        event_ids << "#{entity}_#{timestamp_at_midnight}"
      end

      event_ids << event_name

      case type
      when 'star'
        html = "<a href=\"https://github.com/#{entity['actor']['login']}\">#{entity['actor']['login']}</a> starred <a href=\"https://github.com/#{entity['repo']['name']}\">#{entity['repo']['name'][/\/(.+)/, 1]}</a>"
      when 'fork'
        html = "<a href=\"https://github.com/#{entity['actor']['login']}\">#{entity['actor']['login']}</a> forked <a href=\"https://github.com/#{entity['repo']['name']}\">#{entity['repo']['name'][/\/(.+)/, 1]}</a> to <a href=\"https://github.com/#{entity['payload']['forkee']['full_name']}\">#{entity['payload']['forkee']['full_name']}</a>"
      when 'follow'
        html = "<a href=\"https://github.com/#{entity['login']}\">#{entity['login']}</a> started following you"
      when 'unfollow'
        html = "<a href=\"https://github.com/#{entity['login']}\">#{entity['login']}</a> is not following you anymore"
      when 'deleted'
        html = "#{entity} that was following you has been deleted"
      end

      text = html.gsub(/<br\s?\/?>/, "\r\n").gsub(/<\/?[^>]*>/, '')

      emailEvents << {:html => html, :text => text, :timestamp => event['timestamp']}
    end

    emailEvents = inject_day(emailEvents) unless user['notifications_frequency'] == 'asap'

    expiry = (Time.now + 31536000).to_i.to_s

    digest = OpenSSL::Digest.new('sha512')
    hmac = OpenSSL::HMAC.hexdigest(digest, CONFIG['secret'], user['github_id'] + expiry)

    unsubscribe_url = URI.escape("https://#{CONFIG['domain']}/unsubscribe?id=#{user['github_id']}&expiry=#{expiry}&v=#{hmac}")

    to = user['email']
    subject = 'GitHub Notifier'
    case user['notifications_frequency']
    when 'asap'
      subject += ' notification'
    when 'daily'
      subject += ' daily report'
    when 'weekly'
      subject += ' weekly report'
    end

    SendEmail.perform_async(
      to,
      subject,
      'html',
      'notification',
      {:events => emailEvents, :unsubscribe_url => unsubscribe_url, :site_url => "https://#{CONFIG['domain']}/?utm_source=notifications&utm_medium=email&utm_campaign=timeline&utm_content=#{user['notifications_frequency']}"},
      events_list_key,
      "#{CONFIG['redis']['namespace']}:locks:email:#{user['github_id']}",
      event_ids,
      "#{CONFIG['redis']['namespace']}:users:#{user['github_id']}"
    ) unless user['email_confirmed'] == "0" || emailEvents.empty?

  end

  def inject_day(events)
    previousEvent = nil
    events.map! do |event|
      if previousEvent.nil? || (Time.at(previousEvent[:timestamp]).strftime('%d') != Time.at(event[:timestamp]).strftime('%d'))
        event[:day] = Time.at(event[:timestamp]).strftime('%A, %B %e')
      end
      previousEvent = event
    end

    events
  end

end
