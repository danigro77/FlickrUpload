require 'flickraw'
require 'optparse'
require "yaml"

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

@user_keys = YAML::load(File.open("user.yml"))

unless @options[:user]
  puts "Flickr UserName is needed:"
  @options[:user] = gets.chomp
end

unless @options[:api_key]
  if @user_keys[@options[:user]][:api_key]
    @options[:api_key] = @user_keys[@options[:user]][:api_key]
  else
    puts "Flickr API KEY is needed:"
    @options[:api_key] = gets.chomp
  end
end

unless @options[:shared_secret]
  if @user_keys[@options[:user]][:shared_secret]
    @options[:shared_secret] = @user_keys[@options[:user]][:shared_secret]
  else
    puts "Flickr SHARED SECRET is needed:"
    @options[:shared_secret] = gets.chomp
  end
end

unless @options[:permit]
  puts "Wanted rights are needed: read, write, delete"
  @options[:permit] = gets.chomp
end

FlickRaw.api_key = @options[:api_key]
FlickRaw.shared_secret = @options[:shared_secret]

token = flickr.get_request_token
auth_url = flickr.get_authorize_url(token['oauth_token'], :perms => @options[:permit])

puts "Open this url in your process to complete the authication process:"
puts "#{auth_url}"
puts "Copy here the number given when you complete the process."
verify = gets.strip

begin
  flickr.get_access_token(token['oauth_token'], token['oauth_token_secret'], verify)
  login = flickr.test.login
  puts "You are now authenticated as #{login.username} with token #{flickr.access_token} and secret #{flickr.access_secret}"
rescue FlickRaw::FailedResponse => e
  puts "Authentication failed : #{e.msg}"
end

begin
  @user_keys[login.username]['api_key'] = @options[:api_key]
  @user_keys[login.username]['shared_secret'] = @options[:shared_secret]
  @user_keys[login.username]['access_token'] = flickr.access_token
  @user_keys[login.username]['access_secret'] = flickr.access_secret
  File.open('user.yml', 'w') { |f| f.write @user_keys.to_yaml }
  puts "Data is written to file"
rescue => e
  puts "FAILED to write to config file"
  puts "\t#{e.message}"
  exit
end

