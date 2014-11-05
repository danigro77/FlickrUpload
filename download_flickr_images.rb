require 'flickraw'
require 'optparse'
require "yaml"
require 'term/ansicolor'
require 'fileutils'
require "open-uri"

require_relative 'services/user.rb'
require_relative 'services/flickr.rb'
require_relative 'services/download.rb'
require_relative 'services/download_photo.rb'
require_relative 'services/download_control.rb'

include Term::ANSIColor

@options = {}

opt_parse = OptionParser.new do |opts|
  opts.banner = "Usage: download_flickr_images.rb [options]"

  opts.on('-u', '--user USER', 'Input your Flickr user name') do |u|
    @options[:user] = u
  end

  opts.on('-t', '--target TARGET', 'Input the full path to target directory') do |t|
    @options[:target_directory] = t
  end

  opts.on('-s', '--source S1,S2,S3', Array, "Input the directories you want to download. Example: -s bla_1,'bla 2' \nUse -A if you want to download all.") do |s|
    @options[:source_directories] = s
  end

  opts.on('-A', '--all', 'Use -A if you want to download all albums from Flickr') do
    @options[:all_albums] = true
  end

  opts.on('-a', '--album', "If this is set, you want all images in your target directory. \nElse: It creates directories with the source album name inside your target directory.") do
    @options[:in_same_album] = true
  end

  opts.on( '-h', '--help', 'Display help screen' ) do
    puts opts
    exit
  end
end

opt_parse.parse!

def album_exists?(title)
  existing = false
  @download_control.all_albums.each do |album|
    if album['title'] == title
      existing = true
      @download.album_id = album['id']
    end
  end
  existing
end

def set_user
  if @options[:user]
    @user = User.new(@options[:user])
    unless @user.complete?
      puts bold, "Your user is not complete!", reset
      puts "ruby create_flickr_user.rb -u YourFlickrUserName -k YourApiKey -s YourSharedSecret -p [read, write, delete]"
      exit
    end
  else
    puts bold, "No user entered!", reset
    puts "-u/--user YourFlickrUserName"
    exit
  end
end

def set_target_directory
  if @options[:target_directory]
    @options[:target_directory].match(/\/$/) ? @options[:target_directory] : @options[:target_directory] + '/'
  else
    puts bold, "No target directory entered!", reset
    puts "-t/--target ~/Pictures/my_directory"
    exit
  end
end

def clean_source_directory(index)
  source = @download_control.source_directories[index].strip
  if album_exists?(source)
    source_album = source.split(' ').map! { |str| str.downcase.gsub(/\//, '') }.join('_')
    @download_control.source_directories[index] = source_album
    @download.directory = source_album
  else
    puts bold, "The source directory #{source} does not exist on Flickr!", reset
    puts "Please check your spelling. This album is getting skipped."
    @download_control.skipped_albums << source
    nil
  end
end

def set_source_directories
  if @options[:all_albums]
    @download_control.source_directories = @download_control.all_albums
  elsif @options[:source_directories]
    @download_control.source_directories = @options[:source_directories]
  else
    puts bold, "No source directory entered!", reset
    puts "-s/--source FlickrSourceDirectory"
    exit
  end
end

def error_message(msg, error)
  print red, "#{msg}\n"
  print "\t#{error}\n", reset
end

def login
  Flickr.connect_with(@user)
  Flickr.authenticate(@user)
  @flickr_user = Flickr.get_user
  @flickr_user_id = @flickr_user.nsid
end

def download_to_target_directory(download)
  begin
    open(download.target_directory + @image.title, 'wb') do |file|
      file << open(@image.source).read
    end
    @counter += 1
  rescue => e
    error_message("FAILED to download #{download.target_directory + @image.title}", e.message)
    @download_control.failed_downloads[download.source_directory] ||= []
    @download_control.failed_downloads[download.source_directory] << @image.source
  end
end

def image_number(total)
  total_length = total.to_s.length
  "%0#{total_length}d" % @counter
end

def prepare_image_for_download(download, img_id, size)
  @image = DownloadPhoto.new(img_id)
  @image = Flickr.get_photo_url(@image, size)
  @image.type = @image.get_type_from_source
  @image.title = "#{download.directory}_#{image_number(download.total)}.#{@image.type}"
end

def download_images(download)
  download.photo_ids.each do |img_id|
    @download_control.sizes.each do |size|
      prepare_image_for_download(download, img_id, size)
      download_to_target_directory(download)
    end
  end
end

def create_target_directory(download)
  dir_path = download.target_directory

  unless File.directory?(dir_path)
    begin
      FileUtils.mkdir_p(dir_path)
    rescue => e
      error_message("FAILED to create the directory in #{dir_path}.\nPlease origin your path from your home directory.", e.message)
    end
  end
end

def fill_download(source_album_title)
  @download.target_directory = set_target_directory
  @download.source_directory = source_album_title
  @download.in_same_album = true                                    if @options[:in_same_album]
  @download.target_directory += (@download.source_directory + '/')  unless @download.in_same_album
  @download.photo_ids = Flickr.get_photos_in_album(@download)
end

def init_program
  set_user
  login

  @download_control = DownloadControl.new
  @download_control.all_albums = Flickr.get_user_albums(@flickr_user_id, @user)

  set_source_directories

  @download_control.source_directories.each_with_index do |source_album_title, index|
    @download = Download.new
    valid_directory = clean_source_directory(index)
    if valid_directory
      @download.album_title = source_album_title
      fill_download(@download_control.source_directories[index])
      @download_control.downloads << @download
    end
  end

end


def download_images_from_album
  init_program

  @download_control.downloads.each do |download|
    download.total = download.photo_ids.length
    puts "Start download #{download.album_title}"
    puts "\t\tTotal images: #{download.total}"
    @counter = 1
    create_target_directory(download)
    download_images(download)
  end
end

download_images_from_album
