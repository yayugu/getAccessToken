require 'erb'
require 'rubygems'
require 'json'
require 'oauth'
require 'haml'
require 'sinatra'


helpers do
  include Rack::Utils
  alias_method :h, :escape_html

  def oauth_consumer(key, secret)
    OAuth::Consumer.new(key, secret, :site => 'https://api.twitter.com')
  end

  def base_url
    default_port = (request.scheme == "http") ? 80 : 443
    port = (request.port == default_port) ? "" : ":#{request.port.to_s}"
    "#{request.scheme}://#{request.host}#{port}"
  end

  def get_screen_name(access_token)
    JSON.parse(
      access_token.get(
        "https://api.twitter.com/1.1/account/verify_credentials.json").body)['screen_name']
  end
end

configure do
  enable :sessions
  set :public_dir, File.dirname(__FILE__) + '/public'
  set :views, File.dirname(__FILE__) + '/views'
end

before do
  if session[:access_token]
    @access_token = get_access_token(session[:access_token], session[:access_token_secret])
  else
    @access_token = nil
  end
end


get '/stylesheet.css' do
  content_type 'text/css', :charset => 'utf-8'
  sass :stylesheet
end


get '/' do
  haml :index
end


post '/request_token' do
  callback_url = "#{base_url}/access_token"
  request_token = oauth_consumer(params[:consumer_key], params[:consumer_secret]).get_request_token(:oauth_callback => callback_url)
  session[:request_token] = request_token.token
  session[:request_token_secret] = request_token.secret
  session[:consumer_key] = params[:consumer_key]
  session[:consumer_secret] = params[:consumer_secret]
  redirect request_token.authorize_url
end


get '/access_token' do
  request_token = OAuth::RequestToken.new(
    oauth_consumer(session[:consumer_key], session[:consumer_secret]), session[:request_token], session[:request_token_secret])
  begin
    @access_token = request_token.get_access_token({},
      :oauth_token => params[:oauth_token],
      :oauth_verifier => params[:oauth_verifier])
  rescue OAuth::Unauthorized => @exception
    return erb %{oauth failed: <%=h @exception.message %>}
  end
  @screen_name = get_screen_name(@access_token)
  haml :access_token
end

