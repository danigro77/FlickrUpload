require 'flickraw'
require 'optparse'
require "yaml"
require 'term/ansicolor'

require_relative 'user.rb'

include Term::ANSIColor

@options = {}

opt_parse = OptionParser.new do |opts|
  opts.banner = "Usage: upload_user.rb [options]"

  opts.on('-u', '--user USER', 'Set Flickr username') do |u|
    @options[:user] = u
  end

  opts.on('-k', '--api_key API_KEY', 'Input Flickr api_key') do |k|
    @options[:api_key] = k
  end

  opts.on('-s', '--shared_secret SHARED_SECRET', 'Input Flickr shared_secret') do |s|
    @options[:shared_secret] = s
  end

  opts.on('-p', '--permit PERMIT', 'possible: read, delete, write') do |p|
    @options[:permit] = p
  end

  opts.on( '-h', '--help', 'Display this screen' ) do
    puts opts
    exit
  end
end

opt_parse.parse!

def set_user
  if @options[:user]
    @user = User.new(@options[:user])
  else
    print "Flickr UserName is needed: "
    @user = User.new(gets.chomp)
  end
end

def input_key_secrets(type, text)
  if @options[type]
    @options[type]
  else
    puts text
    gets.chomp
  end
end

def set_api_credentials
  api_key = input_key_secrets(:api_key, "Flickr API KEY is needed:")
  shared_secret = input_key_secrets(:shared_secret, "Flickr SHARED SECRET is needed:")
  permit = input_key_secrets(:permit, "Wanted rights are needed: read, write, delete")

  @user.save_api_credentials(api_key, shared_secret, permit)
end

def set_access_credentials(permit)
  begin
    FlickRaw.api_key = @user.api_key
    FlickRaw.shared_secret = @user.shared_secret

    token = flickr.get_request_token
    auth_url = flickr.get_authorize_url(token['oauth_token'], :perms => permit)
  rescue => e
    print red, "FAILED to connect to API with these credentials. Please check them!\n", reset
    puts "API KEY: #{@user.api_key}"
    puts "SHARED SECRET: #{@user.shared_secret}"
    set_api_credentials
  end

  puts "Open this url in your process to complete the authentication process:"
  puts "#{auth_url}"
  puts "Copy here the number given when you complete the process."
  verify = gets.strip

  begin
    flickr.get_access_token(token['oauth_token'], token['oauth_token_secret'], verify)
    login = flickr.test.login
    puts "You are now authenticated as #{login.username} and have the right to #{permit} on/to Flickr."
  rescue FlickRaw::FailedResponse => e
    print red, "Authentication failed : #{e.msg}\n", reset
  end

  @user.save_access_credentials(flickr.access_token, flickr.access_secret, permit)
end


def create_update_user
  set_user
  if @user.api_key && @user.shared_secret
    puts "Do you want to change your permissions? [y/n]"
    current = @user.permission ? @user.permission : 'n/a'
    puts "Your permission is currently: #{current}"
    case gets[0].downcase
      when 'y'
        permit = input_key_secrets(:permit, "Wanted rights are needed: read, write, delete")
        set_access_credentials(permit)
      else
        if @user.permission
          set_access_credentials(@user.permission)
        else
          puts "Permissions are needed!"
          permit = input_key_secrets(:permit, "Wanted rights are needed: read, write, delete")
          set_access_credentials(permit)
        end
    end
  else
    set_api_credentials
    set_access_credentials(@user.permission)
  end
end

create_update_user
