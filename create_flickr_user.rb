require 'flickraw'
require 'optparse'
require "yaml"
require 'term/ansicolor'

require_relative 'services/user.rb'
require_relative 'services/flickr.rb'

include Term::ANSIColor

@options = {}

opt_parse = OptionParser.new do |opts|
  opts.banner = "Usage: create_flickr_user.rb [options]"

  opts.on('-u', '--user USER', 'Input Flickr username') do |u|
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

# ################ #
#  ENSURE OPTIONS  #
# ################ #

def set_user
  if @options[:user]
    @user = User.new(@options[:user])
  else
    puts bold, "No user entered!", reset
    puts "-u/--user YourFlickrUserName"
    exit
  end
end

def set_api_key
  if @options[:api_key]
    @user.api_key = @options[:api_key]
  end
  unless @user.api_key
    puts bold, "No API Key entered or stored!", reset
    puts "-k/--api_key YourFlickrApiKey"
    exit
  end
end

def set_shared_secret
  if @options[:shared_secret]
    @user.shared_secret = @options[:shared_secret]
  end
  unless @user.shared_secret
    puts bold, "No Shared Secret entered or stored!", reset
    puts "-s/--shared_secret YourFlickrSharedSecret"
    exit
  end
end

def set_permit
  if @options[:permit]
    @user.permission = @options[:permit]
  end
  unless @user.permission
    puts bold, "No Flickr Permission entered or stored!", reset
    puts "-p/--permit [read, write (+read), delete (+write+read)]"
    exit
  end
end

# ################# #
#  SET CREDENTIALS  #
# ################# #

def set_api_credentials
  set_api_key
  set_shared_secret
  set_permit
end

def set_access_credentials
  Flickr.connect_with(@user)
  credentials = Flickr.get_auth_keys(@user)
  @user.access_token = credentials[:token]
  @user.access_secret = credentials[:secret]
end

# ############ #
#  RUN PROGRAM #
# ############ #

def create_update_user
  set_user
  set_api_credentials
  set_access_credentials
  @user.save_to_yaml    if @user.complete?
end

create_update_user
