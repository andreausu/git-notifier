#!/usr/bin/env ruby

require 'haml'
require 'json'
require 'github_api'
require 'pp'

class GitNotifier < Sinatra::Base

  @additional_js = nil

  configure :development do
    register Sinatra::Reloader
  end

  configure :production do
    set :production, true
  end

  configure do
    config_file = File.dirname(__FILE__) + '/config.yml'
    fail "Configuration file " + config_file + " missing!" unless File.exist?(config_file)
    config = YAML.load_file(config_file)

    redis_conn = proc {
      Redis.new(
        :driver => :hiredis,
        :host => config['redis']['host'],
        :port => config['redis']['port'],
        :db => config['redis']['db'],
        network_timeout: 5
      )
    }

    Sidekiq.configure_client do |cfg|
      cfg.redis = ConnectionPool.new(size: 25, &redis_conn)
    end

    set :CONFIG, config

    use Rack::Session::Cookie, :expire_after => 2592000, :secret => config['secret'] # 30 days

    use Rack::Csrf, :raise => true, :header => 'x-csrf-token'
    use Rack::Flash
  end

  before do
    @token = session['session_id']
    @session = session
    @additional_js = []
    @deploy_id = settings.CONFIG['deploy_id']
    @page_title = 'Notifications for stars, forks, follow and unfollow'
    @custom_url = nil
  end

  get '/' do
    if session[:github_token]
      email = Sidekiq.redis do |conn|
        conn.hget("#{settings.CONFIG['redis']['namespace']}:users:#{session[:github_id]}", 'email')
      end
      if !email
        github = Github.new(
          client_id: settings.CONFIG['github']['client_id'],
          client_secret: settings.CONFIG['github']['client_secret'],
          oauth_token: session[:github_token]
        )

        email_addresses = github.users.emails.list.to_a
        email_addresses.map! { |e| e.is_a?(String) ? e : e.email}
        @additional_js = ['mailcheck.min.js']
        @custom_url = 'signup/homepage'
        NewRelic::Agent.set_transaction_name("GitNotifier/GET #{@custom_url}")
        haml :signup, :locals => {:email_addresses => email_addresses}
      else
        session[:email] = email
        @additional_js = ['spin.js', 'jquery.spin.js']
        @custom_url = 'timeline'
        NewRelic::Agent.set_transaction_name("GitNotifier/GET #{@custom_url}")
        @page_title = 'Profile'
        haml :events, :locals => {:github_id => session[:github_id]}
      end
    else
      haml :index, :locals => {:index => true}
    end
  end

  get '/authorize' do
    begin
      github = Github.new(client_id: settings.CONFIG['github']['client_id'], client_secret: settings.CONFIG['github']['client_secret'])
      redirect github.authorize_url scope: 'user:email'
    rescue Exception => e
      NewRelic::Agent.notice_error(e)
      flash[:danger] = 'We experienced an error while connecting to GitHub, please try again.'
      redirect '/', 302
    end
  end

  get '/authorize/callback' do
    if !params[:code]
      flash[:danger] = 'Something went wrong, please try again.'
      redirect '/', 302
    end

    begin
      github = Github.new(client_id: settings.CONFIG['github']['client_id'], client_secret: settings.CONFIG['github']['client_secret'])
      token = github.get_token(params[:code])
    rescue Exception => e
      NewRelic::Agent.notice_error(e)
      flash[:danger] = 'We experienced an error while connecting to GitHub, please try again.'
      redirect '/', 302
    end

    session[:github_token] = token.token

    user = nil
    Sidekiq.redis do |conn|
      user = conn.get("#{settings.CONFIG['redis']['namespace']}:tokens:#{token.token}")
      user = conn.hmget("#{settings.CONFIG['redis']['namespace']}:users:#{user}", 'login', 'github_id', 'email') if user
    end

    if user && user[0] && user[2]
      session[:github_login] = user[0]
      session[:github_id] = user[1]
      redirect '/'
    else

      begin
        github = Github.new(
          client_id: settings.CONFIG['github']['client_id'],
          client_secret: settings.CONFIG['github']['client_secret'],
          oauth_token: session[:github_token]
        )

        user = github.users.get
      rescue Exception => e
        NewRelic::Agent.notice_error(e)
        flash[:danger] = 'We experienced an error while connecting to GitHub, please try again.'
        redirect '/', 302
      end

      session[:github_login] = user[:login]
      session[:github_id] = user[:id]

      current_timestamp = Time.now.to_i

      userExists = nil

      Sidekiq.redis do |conn|

        userExists = conn.exists("#{settings.CONFIG['redis']['namespace']}:users:#{user[:id]}")

        conn.multi do
          conn.set("#{settings.CONFIG['redis']['namespace']}:tokens:#{token.token}", user[:id])
          if userExists
            # The user already exists, just update the token
            conn.hset(
              "#{settings.CONFIG['redis']['namespace']}:users:#{user[:id]}",
              :token,
              token.token
            )
          else
            conn.hmset(
              "#{settings.CONFIG['redis']['namespace']}:users:#{user[:id]}",
              :login, user[:login],
              :last_event_id, 0,
              :token, token.token,
              :github_id, user[:id],
              :registered_on, current_timestamp,
              :notifications_frequency, 'daily',
              :last_email_sent_on, current_timestamp,
              :last_email_queued_on, current_timestamp,
              :first_check_completed, 0,
              :email_confirmed, 0
            )
          end
        end
      end

      if userExists
        redirect '/', 302
      end

      NotificationsChecker.perform_async(
        "#{settings.CONFIG['redis']['namespace']}:users:#{user[:id]}",
        true
      )

      email_addresses = github.users.emails.list.to_a
      email_addresses.map! { |em| em.is_a?(String) ? em : em.email}
      @additional_js = ['mailcheck.min.js']
      haml :signup, :locals => {:email_addresses => email_addresses}
    end
  end

  post '/signup' do
    email = nil
    email_confirmed = 0

    if params[:email] == 'other_email'
      email = params[:other_email]
    else
      email = params[:email]
      email_confirmed = 1
    end

    if !email.match(/.+@.+\..+/)
      flash[:danger] = 'Please enter a valid email address'
      redirect "/", 302
    end

    Sidekiq.redis do |conn|
      conn.hmset(
        "#{settings.CONFIG['redis']['namespace']}:users:#{session[:github_id]}",
        :email, email,
        :email_confirmed, email_confirmed
      )
    end
    session[:email] = email

    if params[:email] == 'other_email'

      expiry = (Time.now + 31536000).to_i.to_s

      digest = OpenSSL::Digest.new('sha512')
      hmac = OpenSSL::HMAC.hexdigest(digest, settings.CONFIG['secret'], session[:github_id].to_s + params[:other_email] + expiry)

      link = "#{request.scheme}://#{request.host_with_port}/signup/confirm?id=#{session[:github_id]}&email=#{CGI.escape(params[:other_email])}&expiry=#{expiry}&v=#{hmac}"

      Sidekiq::Client.push(
        'queue' => 'send_email_signup',
        'class' => SendEmail,
        'args' => [email, 'Confirm your GitHub Notfier email address!', 'html', 'confirm', {:confirm_link => link}]
      )

      flash.now[:success] = "We have sent an email to #{email}, please open it and click on the link inside to activate your account."
    end

    if settings.CONFIG['email_dev_on_signup']
      Sidekiq::Client.push(
        'queue' => 'send_email',
        'class' => SendEmail,
        'args' => [settings.CONFIG['dev_email_address'], 'New user signup!', 'text', 'empty', {:content => "A new user just signed up! https://github.com/#{session[:github_login]}"}]
      )
    end

    haml :preferences, :locals => {
      :disabled_notifications_type => [],
      :current_frequency => 'daily',
      :notifications_type => settings.CONFIG['notifications_type'],
      :notifications_frequency => settings.CONFIG['notifications_frequency']
    }
  end

  get '/signup/confirm' do
    redirect "/", 302 if !params[:id] || !params[:email] || !params[:expiry] || !params[:v]

    github_id = params[:id]
    email = params[:email]
    expiry = params[:expiry]
    hmac = params[:v]

    digest = OpenSSL::Digest.new('sha512')
    redirect "/", 302 if hmac != OpenSSL::HMAC.hexdigest(digest, settings.CONFIG['secret'], github_id + email + expiry)

    if expiry.to_i < Time.now.to_i
      flash[:warning] = 'Expired link'
      redirect "/", 302
    end

    user_email = Sidekiq.redis do |conn|
      conn.hget("#{settings.CONFIG['redis']['namespace']}:users:#{github_id}", :email)
    end
    redirect "/", 302 if !user_email or email != user_email

    Sidekiq.redis do |conn|
      conn.hset("#{settings.CONFIG['redis']['namespace']}:users:#{github_id}", :email_confirmed, 1)
    end

    flash[:success] = "Email address #{email} successfully verified!"
    redirect "/", 302
  end

  get '/api/events' do

    return 403 if !session[:github_id]

    github_id = session[:github_id]
    events = []
    eof = true

    user = Sidekiq.redis do |conn|
      conn.hgetall("#{settings.CONFIG['redis']['namespace']}:users:#{github_id}")
    end

    if user['first_check_completed'] == "0"

      page = params[:page] ||= 1

      begin
        github = Github.new(
          client_id: settings.CONFIG['github']['client_id'],
          client_secret: settings.CONFIG['github']['client_secret'],
          oauth_token: user['token']
        )
        response = github.activity.events.received(user['login'], page: page)
      rescue Exception => e
        NewRelic::Agent.notice_error(e)
        return 503
      end

      response = response.to_a
      response.each do |event|
        case event['type']
        when 'WatchEvent'
          events << {'type' => 'star', 'entity' => event} if event['repo']['name'].include? user['login']
        when 'ForkEvent'
          events << {'type' => 'fork', 'entity' => event} if event['repo']['name'].include? user['login']
        end
      end

      eof = false if response.length >= 30

    else
      events = Sidekiq.redis do |conn|
        conn.lrange("#{settings.CONFIG['redis']['namespace']}:events:#{github_id}", 0, 99)
      end
      events ||= []
      events.map! {|event| event = JSON.parse event}
    end

    events.map! do |event|
      email_body = ''
      type = event['type']
      entity =  event['entity']
      case type
      when 'star'
        email_body += "<a href=\"https://github.com/#{entity['actor']['login']}\">#{entity['actor']['login']}</a> starred your project <a href=\"https://github.com/#{entity['repo']['name']}\">#{entity['repo']['name']}</a>"
      when 'fork'
        email_body += "<a href=\"https://github.com/#{entity['actor']['login']}\">#{entity['actor']['login']}</a> forked your project <a href=\"https://github.com/#{entity['repo']['name']}\">#{entity['repo']['name']}</a> to <a href=\"https://github.com/#{entity['payload']['forkee']['full_name']}\">#{entity['payload']['forkee']['full_name']}</a>"
      when 'follow'
        email_body += "<a href=\"https://github.com/#{entity['login']}\">#{entity['login']}</a> started following you"
      when 'unfollow'
        email_body += "<a href=\"https://github.com/#{entity['login']}\">#{entity['login']}</a> is not following you anymore"
      when 'deleted'
        email_body += "#{entity} that was following you has been deleted"
      end
      {:body => email_body, :timestamp => (defined?(event['timestamp']) && !event['timestamp'].nil? ? event['timestamp'] : ''), :type => type}
    end

    JSON.generate({:meta => {:eof => eof}, :objects => events})

  end

  patch '/api/user/preferences' do

    return 403 unless session[:github_id]

    request.body.rewind
    body = request.body.read
    begin
      body = JSON.parse(body)
    rescue Exception => e
      NewRelic::Agent.notice_error(e)
      return 403
    end

    disabled_notifications_type = nil
    notifications_frequency = nil

    if body['disabled_notifications_type']
      disabled_notifications_type = body['disabled_notifications_type']
      disabled_notifications_type.each do |dnt|
        return 403 unless settings.CONFIG['notifications_type'].include? dnt
      end
      Sidekiq.redis do |conn|
        conn.hset(
          "#{settings.CONFIG['redis']['namespace']}:users:#{session[:github_id]}",
          'disabled_notifications_type',
          JSON.generate(disabled_notifications_type)
        )
      end
    end

    if body['notifications_frequency']
      notifications_frequency = body['notifications_frequency']
      if settings.CONFIG['notifications_frequency'].include? notifications_frequency
        Sidekiq.redis do |conn|
          conn.hset(
            "#{settings.CONFIG['redis']['namespace']}:users:#{session[:github_id]}",
            'notifications_frequency', notifications_frequency
          )
        end
      else
        return 403
      end
    end

    return [200, '{}']
  end

  get '/unsubscribe' do

    redirect "/", 302 if !params[:id] || !params[:expiry] || !params[:v]

    @page_title = 'Unsubscribe'

    github_id = params[:id]
    expiry = params[:expiry]
    hmac = params[:v]

    digest = OpenSSL::Digest.new('sha512')
    redirect "/", 302 if hmac != OpenSSL::HMAC.hexdigest(digest, settings.CONFIG['secret'], github_id + expiry)
    if expiry.to_i < Time.now.to_i
      flash[:warning] = 'Expired link.'
      redirect "/", 302
    end
    redirect "/", 302 if Sidekiq.redis { |conn| !conn.exists("#{settings.CONFIG['redis']['namespace']}:users:#{github_id}") }

    res = Sidekiq.redis do |conn|
      conn.hmget(
        "#{settings.CONFIG['redis']['namespace']}:users:#{github_id}",
        'disabled_notifications_type',
        'notifications_frequency'
      )
    end
    notifications_frequency = res[1]
    disabled_notifications = res[0]
    if disabled_notifications
      disabled_notifications = JSON.parse(disabled_notifications)
    else
      disabled_notifications = []
    end

    timestamp = Time.now.to_i.to_s
    hmac = OpenSSL::HMAC.hexdigest(digest, settings.CONFIG['secret'], github_id + timestamp)

    haml :unsubscribe, :locals => {
      :disabled_notifications_type => disabled_notifications,
      :github_id => github_id,
      :current_frequency => notifications_frequency,
      :notifications_type => settings.CONFIG['notifications_type'],
      :notifications_frequency => settings.CONFIG['notifications_frequency'],
      :hmac => hmac,
      :timestamp => timestamp
    }
  end

  post '/unsubscribe' do

    redirect "/", 302 if !params[:id]
    redirect "/", 302 if !params[:timestamp]
    redirect "/", 302 if !params[:v]

    digest = OpenSSL::Digest.new('sha512')
    redirect "/", 302 if params[:v] != OpenSSL::HMAC.hexdigest(digest, settings.CONFIG['secret'], params[:id] + params[:timestamp])

    disabled_notifications_type = nil
    notifications_frequency = nil

    if params[:change_frequency]
      notifications_frequency = params[:notifications_frequency]
    elsif params[:unsubscribe]
      disabled_notifications_type = settings.CONFIG['notifications_type'] - params[:notifications]
    elsif params[:unsubscribe_all]
      disabled_notifications_type = settings.CONFIG['notifications_type']
    else
      redirect "/", 302
    end

    if disabled_notifications_type
      Sidekiq.redis do |conn|
        conn.hset(
          "#{settings.CONFIG['redis']['namespace']}:users:#{params[:id]}",
          'disabled_notifications_type', JSON.generate(disabled_notifications_type)
        )
      end
    else
      Sidekiq.redis do |conn|
        conn.hset(
          "#{settings.CONFIG['redis']['namespace']}:users:#{params[:id]}",
          'notifications_frequency', notifications_frequency
        )
      end
    end

    flash[:success] = 'Sucessfully unsubscribed!'
    redirect '/', 302
  end

  get '/user/preferences' do

    @page_title = 'Preferences'

    github_id = session[:github_id]
    res = Sidekiq.redis do |conn|
      conn.hmget(
        "#{settings.CONFIG['redis']['namespace']}:users:#{github_id}",
        'disabled_notifications_type',
        'notifications_frequency'
      )
    end
    notifications_frequency = res[1]
    disabled_notifications_type = res[0]
    if disabled_notifications_type
      disabled_notifications_type = JSON.parse(disabled_notifications_type)
    else
      disabled_notifications_type = []
    end

    haml :preferences, :locals => {
      :disabled_notifications_type => disabled_notifications_type,
      :current_frequency => notifications_frequency,
      :notifications_type => settings.CONFIG['notifications_type'],
      :notifications_frequency => settings.CONFIG['notifications_frequency'],
      :signup => "false"
    }
  end

  get '/logout' do
    session.clear
    redirect '/'
  end

  get '/faq' do
    @page_title = 'FAQ'
    haml :faq
  end

  helpers do
    def get_menu()
      if @session[:email]
        [
          {:href => '/', :desc => 'Profile'},
          {:href => '/user/preferences', :desc => 'Preferences'},
          {:href => '/faq', :desc => 'FAQ'},
          {:href => '/logout', :desc => 'Logout'}
        ]
      else
        [
          {:href => (request.path_info == '/faq' ? '/' : '') + '#features', :desc => 'Features'},
          {:href => (request.path_info == '/faq' ? '/' : '') + '#tour-head', :desc => 'Tour'},
          {:href => '/faq', :desc => 'FAQ'},
          {:href => (request.path_info == '/faq' ? '/' : '') + '#stack', :desc => 'Stack'},
          {:href => "mailto:#{settings.CONFIG['dev_email_address']}", :desc => 'Contact Us'}
        ]
      end
    end
  end

  def csrf_token()
    Rack::Csrf.csrf_token(env)
  end

  def csrf_tag()
    Rack::Csrf.csrf_tag(env)
  end

  def get_flash(index=false)
    output = ''
    if !flash.keys.empty?
      output = '<div class="container first-cnt">' if index
      output += '
      <div class="alert alert-' + flash.keys[0].to_s +  ' alert-dismissible" role="alert">
      <button type="button" class="close" data-dismiss="alert" aria-label="Close"><span aria-hidden="true">&times;</span></button>
      ' + flash[flash.keys[0]] + '
      </div>'
      output += '</div>' if index
    end
    output
  end

  def get_additional_js()
    add_js = ''
    @additional_js.each do |js|
      add_js += "<script src='/js/#{js}?v=#{@deploy_id}'></script>"
    end

    add_js
  end

  def get_head_js()
    js = ''
    if defined?(settings.production) && settings.production
      pageView = "ga('send', 'pageview');"
      pageView = "ga('send', 'pageview', '/#{@custom_url}');" if @custom_url
      logged_in = (defined?(session[:github_id]) && session[:github_id] ? 1 : 0)

      js += "<script async src='//www.google-analytics.com/analytics.js'></script><script>
        window.ga=window.ga||function(){(ga.q=ga.q||[]).push(arguments)};ga.l=+new Date;
        ga('create', 'UA-59786346-2', 'auto');
        #{pageView}
        ga('set', 'logged_in', #{logged_in});
        </script>"
    end
    js
  end

end
