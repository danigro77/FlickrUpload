require 'flickraw'
require 'optparse'
require "yaml"
require 'term/ansicolor'

include Term::ANSIColor

IMAGE_TYPES = %w(jpeg JPEG jpg JPG png PNG gif GIF tiff TIFF mpeg MPEG mp4 MP4 avi AVI wmv WMV mov MOV mpg MPG mp1 MP1 mp2 MP2 mpv MPV 3gp 3GP m2ts M2TS ogg OGG ogv OGV )
IMAGE_MATCHER = /\.(jpe?g|gif|png|tiff|mpe?g|mp4|avi|wmv|mov|mp1|mp2|mpv|3gp|m2ts|ogg|ogv)$/

@options = {}

opt_parse = OptionParser.new do |opts|
  opts.banner = "Usage: upload_by_folder.rb [options]"

  opts.on('-u', '--user USER', 'Set Flickr username') do |u|
    @options[:user] = u
  end

  opts.on('-p', '--path PATH', 'Set source path') do |p|
    @options[:path] = p
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

unless @options[:path]
  puts bold, red, "You have not passed in a source path.", reset
  puts "Do you want to add a path? [a]"
  puts "Do you want to upload the subdirectories of the program? [u]"
  puts "Do you want to exit the program? [any other key]"
  case gets[0].downcase
    when "a"
      puts
      puts "Please enter the full path ending with /"
      @options[:path] = gets.chomp
    when "u"
      @options[:path] = ''
    else
      puts "upload_by_folder.rb -u UserName123 -p /my/full/path/"
      exit
  end
end

if @options[:user]
  user_keys = YAML::load(File.open("user.yml"))

  if user_keys[@options[:user]]
    api_key = user_keys[@options[:user]]['api_key']
    shared_secret = user_keys[@options[:user]]['shared_secret']
    access_token = user_keys[@options[:user]]['access_token']
    access_secret = user_keys[@options[:user]]['access_secret']
  else
    puts red, "Your Flickr username does not exist! Please retry!", reset
    puts "upload_by_folder.rb -u UserName123 -p /my/full/path/"
    exit
  end
else
  puts red, "Please enter your Flickr username!", reset
  puts "upload_by_folder.rb -u UserName123 -p /my/full/path/"
  exit
end

# ################ #
# LOG INTO FLICKR  #
# ################ #

FlickRaw.api_key= api_key
FlickRaw.shared_secret= shared_secret

token = flickr.get_request_token
auth_url = flickr.get_authorize_url(token['oauth_token'], :perms => 'delete')

# NEEDED for new AUTH-KEYS
    # puts "Open this url in your process to complete the authication process : #{auth_url}"
    # puts "Copy here the number given when you complete the process."
    # verify = gets.strip
    #
    # begin
    #   flickr.get_access_token(token['oauth_token'], token['oauth_token_secret'], verify)
    #   login = flickr.test.login
    #   puts "You are now authenticated as #{login.username} with token #{flickr.access_token} and secret #{flickr.access_secret}"
    # rescue FlickRaw::FailedResponse => e
    #   puts "Authentication failed : #{e.msg}"
    # end

flickr.access_token = access_token
flickr.access_secret = access_secret

login = flickr.test.login
puts "You are now authenticated as #{login.username}"

@user = flickr.people.findByUsername(:username => login.username)
@user_id = @user.nsid
@user_name = @user.username

# ############## #
#     METHODS    #
# ############## #

def photo_upload
  begin
    @photo_id = upload_to_flickr
    puts blue, "Uploaded #{@photo_title} to Flickr.", reset
  rescue => e
    puts red, "FAILED to upload #{@image_full_path}."
    puts "\t#{e.message}", reset
    @failed_uploads << @image_full_path
  end
end

def upload_to_flickr
  flickr.upload_photo(@image_full_path,
                      :title => @photo_title,
                      :description => @album_name,
                      :is_public => 0,
                      :is_family => 0,
                      :is_friend => 0)
end

def create_flickr_set
  begin
    photoset = flickr.photosets.create(:title => @album_name,
                                       :description => 'weiss nicht',
                                       :primary_photo_id => @photo_id)
    @photoset_id = photoset.id
    puts blue, "Created photo set with title #{@album_name}.", reset
  rescue => e
      puts red, "FAILED to create photo set #{@album_name}."
      puts "\t#{e.message}", reset
  end
end

def add_to_flickr_set
  begin
    flickr.photosets.addPhoto(:photoset_id => @photoset_id, :photo_id => @photo_id)
    puts blue, "Added #{@photo_title} to #{@album_name}.", reset
  rescue => e
    puts red, "FAILED to add #{@image_full_path} to set #{@album_name}."
    puts "\t#{e.message}", reset
  end
end

def get_user_albums
  begin
    flickr.photosets.getList(:user_id => @user_id)
  rescue => e
    puts red, "FAILED to get all albums for user #{@user_name}."
    puts "\t#{e.message}", reset
  end
end

def get_set_photo_ids
  photo_ids = []
  begin
    photo_set = flickr.photosets.getPhotos(:photoset_id => @photoset_id)
  rescue => e
    puts red, "FAILED to get all photos for album #{photo_set.title || photo_set.id}."
    puts "\t#{e.message}", reset
  end
  photo_set.photo.each do |photo|
    photo_ids << photo.id
  end
  photo_ids
end

def get_album_name(path)
  @album_name = path.gsub(/\/$/, '').split("/")[-1]
end

def get_album_index
  index = nil
  @existing_albums.each_with_index do |album, i|
    index = i if album.title == @album_name
  end
  index
end

def existing_album(index)
  album = @existing_albums[index]
  puts "-------------------------------------------------"
  print bold, "The album "
  print red, "#{album.title}", reset
  print bold, " already exists.\n", reset
  puts "-------------------------------------------------"
  puts bold, "Options:", reset
  puts "Create a new one with the same name? [n]"
  puts "Skip this upload and remember directory in log? [s]"
  puts "Use existing one and add all images to the set? [a]"
  puts "Exit the program? [any other key]"
  input = gets[0].downcase
  puts "-------------------------------------------------"
  case input
    when "n"
      true
    when "s"
      @skipped_dirs << @path
      @skip = true
    when "a"
      @photoset_id = album.id.to_i
    else
      exit
  end
end

# ######### #
#  PROGRAM  #
# ######### #

def refresh_settings
  @skip = false
  @album_name = nil
  @image_full_path = nil
  @photo_id = nil
  @photoset_id = nil
  @photo_title = nil
  @existing_photos_in_set = []
end

def start_program
  path = @options[:path]
  @source_path = (path.empty? || path.match(/\/$/)) ? path : path + "/"

  @sub_directories =  Dir.glob(@source_path + "**/")

  @existing_albums = get_user_albums
  @failed_uploads = []
  @skipped_dirs = []
  refresh_settings
end

def start_upload_to_flickr
  start_program

  @sub_directories.each do |path|
    @path = path
    refresh_settings
    get_album_name(path)
    images = []
    IMAGE_TYPES.each do  |type|
      images += Dir["#{@path}*.#{type}"]
    end
    if images.length > 0
      puts "================================================="
      puts bold, "  Processing directory #{@path}", reset
      puts "================================================="
      puts "Files in directory: #{images.length}"
      puts
    end

    index = get_album_index
    existing_album(index) if index

    unless @skip
      images.each do |image|
        if image.match(IMAGE_MATCHER)
          @photo_title = File.basename(image).gsub(IMAGE_MATCHER, '')
          @image_full_path = image
          photo_upload
          (images[0] == @image_full_path && @photoset_id.nil?) ? create_flickr_set : add_to_flickr_set
        end
      end
    end
  end

  if @failed_uploads.empty?
    puts
    puts green, bold, "DONE UPLOADING ALL IMAGES", reset
    puts
  else
    puts
    puts red, bold, "================================================="
    puts "================ NOT UPLOADED: =================="
    puts "=================================================", reset
    puts @failed_uploads
    puts
  end

  if @skipped_dirs.empty?
    puts green, bold, "NO DIRECTORIES WERE SKIPPED", reset
    puts
  else
    puts red, bold, "================================================="
    puts "============= SKIPPED DIRECTORIES: =============="
    puts "=================================================", reset
    puts @skipped_dirs
    puts
  end
end

start_upload_to_flickr
