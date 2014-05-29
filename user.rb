require 'flickraw'
require 'optparse'
require "yaml"
require 'term/ansicolor'

class User

  include Term::ANSIColor

  attr_accessor :name, :api_key, :shared_secret, :access_token, :access_secret, :permission

  def initialize(user_name)
    user_keys = YAML::load(File.open("user.yml"))
    @name = user_name
    if user_keys[@name].nil?
      print red, bold "Unknown user!\n", reset
      puts "Do you want to create a new user? [y/n]"
      unless gets[0].downcase == 'y'
        exit
      end
      puts "-------------"
      puts
    end
    @api_key = user_keys[@name] ? user_keys[@name]['api_key'] : nil
    @shared_secret = user_keys[@name] ? user_keys[@name]['shared_secret'] : nil
    @access_token = user_keys[@name] ? user_keys[@name]['access_token'] : nil
    @access_secret = user_keys[@name] ? user_keys[@name]['access_secret'] : nil
    @permission = user_keys[@name] ? user_keys[@name]['permission'] : nil
  end

  def save_api_credentials(key, secret, permission=nil)
    user_keys = YAML::load(File.open("user.yml"))
    puts user_keys
    user_keys[@name] = {}

    self.api_key = user_keys[@name]['api_key'] = key
    self.shared_secret = user_keys[@name]['shared_secret'] = secret
    self.permission = user_keys[@name]['permission'] = permission if permission

    puts user_keys

    begin
      File.open('user.yml', 'w') { |f| f.write user_keys.to_yaml }
      print blue, "Done saving #{type}-key/secret to user.yml.\n", reset
    rescue => e
      print red, "FAILED to save API credentials to user.yml.\n"
      print "\t#{e.message}\n", reset
    end
  end

  def save_access_credentials(token, secret, permission=nil)
    user_keys = YAML::load(File.open("user.yml"))

    self.access_token = user_keys[@name]['access_token'] = token
    self.access_secret = user_keys[@name]['access_secret'] = secret
    self.permission = user_keys[@name]['permission'] = permission if permission

    begin
      File.open('user.yml', 'w') { |f| f.write user_keys.to_yaml }
      print blue, "Done saving #{type}-key/secret to user.yml.\n"
    rescue => e
      print red, "FAILED to save ACCESS credentials to user.yml.\n"
      print "\t#{e.message}\n", reset
    end
  end

  def complete?
    complete = self && self.name && self.api_key && self.shared_secret && self.access_token && self.access_secret
    unless complete
      print red, bold "Incomplete User!\n", reset
      puts "\tPlease run 'ruby upload_user.rb' and follow the steps!"
    end
    complete
  end

end