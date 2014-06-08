require 'flickraw'
require 'optparse'
require "yaml"
require 'term/ansicolor'

class User

  include Term::ANSIColor

  attr_accessor :name, :api_key, :shared_secret, :access_token, :access_secret, :permission

  def initialize(user_name)
    @user_keys ||= load_yaml
    @name = user_name
    @api_key = @user_keys[@name] ? @user_keys[@name]['api_key'] : nil
    @shared_secret = @user_keys[@name] ? @user_keys[@name]['shared_secret'] : nil
    @access_token = @user_keys[@name] ? @user_keys[@name]['access_token'] : nil
    @access_secret = @user_keys[@name] ? @user_keys[@name]['access_secret'] : nil
    @permission = @user_keys[@name] ? @user_keys[@name]['permission'] : nil
  end

  def save_to_yaml
    @user_keys ||= load_yaml
    @user_keys[@name] = {}
    @user_keys[@name]['api_key'] = @api_key
    @user_keys[@name]['shared_secret'] = @shared_secret
    @user_keys[@name]['access_token'] = @access_token
    @user_keys[@name]['access_secret'] = @access_secret
    @user_keys[@name]['permission'] = @permission
    begin
      File.open('user.yml', 'w+') { |f| f.write @user_keys.to_yaml }
      print blue, "Saved #{@name}'s credentials to user.yml.\n", reset
    rescue => e
      print red, "FAILED to save API credentials to user.yml.\n"
      print "\t#{e.message}\n", reset
    end
  end

  def load_yaml
    YAML::load(File.open("user.yml", "r")) || {}
  end

  def complete?
    self && self.name && self.api_key && self.shared_secret && self.access_token && self.access_secret && self.permission
  end

end
