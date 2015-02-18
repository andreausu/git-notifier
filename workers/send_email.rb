require 'mail'
require 'pp'
require 'json'
require 'haml'

class SendEmail
  include Sidekiq::Worker
  sidekiq_options :queue => :send_email
  def perform(to, subject, content_type = 'text', template = nil, locals = {}, delete_key = nil, lock_key = nil, lock_id = nil, user_id = nil)

    raise "Missing template!" unless template

    if lock_id && Sidekiq.redis { |conn| conn.zscore(lock_key, JSON.generate(lock_id)) }
      puts "Email already sent! #{lock_id} found in #{lock_key}"
      return
    end

    mail = Mail.new do
      from     CONFIG['mail']['from']
      to       to
      subject  subject
    end

    textTemplate = File.dirname(__FILE__) + "/../views/email/#{template}.txt"
    textBody = Haml::Engine.new(File.read(textTemplate)).render(Object.new, locals)

    if content_type == 'html'

      htmlTemplate = File.dirname(__FILE__) + "/../views/email/#{template}.haml"
      htmlBody = Haml::Engine.new(File.read(htmlTemplate)).render(Object.new, locals)

      html_part = Mail::Part.new do
        content_type 'text/html; charset=UTF-8'
        body htmlBody
      end
      text_part = Mail::Part.new do
        body textBody
      end

      mail.html_part = html_part
      mail.text_part = text_part
    else
      mail.body textBody
    end

    if CONFIG['mail']['method'] == 'sendmail'
      mail.delivery_method(:sendmail)
    else
      mail.delivery_method(
        :smtp,
        address: CONFIG['mail']['host'],
        port: CONFIG['mail']['port'],
        user_name: CONFIG['mail']['user'],
        password: CONFIG['mail']['password']
      )
    end

    mail.deliver

    Sidekiq.redis do |conn|
      conn.hset(user_id, :last_email_sent_on, Time.now.to_i) if user_id
      conn.del(delete_key) if delete_key
      conn.zadd(lock_key, Time.now.to_i, JSON.generate(lock_id)) if lock_id
    end

  end
end
