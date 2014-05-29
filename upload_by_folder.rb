require 'flickraw'
require 'optparse'
require "yaml"
require 'term/ansicolor'

require_relative 'User'
require_relative 'Upload'
require_relative 'Image'
require_relative 'Album'

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

def set_path
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
end

def set_user
  if @options[:user]
    @user = User.new(@options[:user])
    exit unless @user.complete?
  else
    puts "Please enter you Flickr user name:"
    @user = User.new(gets.chomp)
    exit unless @user.complete?
  end
end

def set_upload_behavior
  puts "-------------------------------------------------"
  print bold, "What should the program do, if finds \n"
  print "\ta new album with the same name as \n"
  print red, "\tan existing album?\n", reset
  puts "Create a new one with the same name? [n]"
  puts "Skip this upload and remember directory in log? [s]"
  puts "Use existing one and add all images to the set? [a]"
  puts "Exit the program? [any other key]"
  input = gets[0].downcase
  puts "-------------------------------------------------"
  case input
    when 'n' then @upload.behavior =  :new_album
    when 's' then @upload.behavior =  :skip_album
    when 'a' then @upload.behavior =  :add_to_album
    else
      exit
  end
end

# ################ #
# LOG INTO FLICKR  #
# ################ #

def login
  FlickRaw.api_key = @user.api_key
  FlickRaw.shared_secret = @user.shared_secret

  flickr.access_token = @user.access_token
  flickr.access_secret = @user.access_secret

  login = flickr.test.login
  puts "You are now authenticated as #{login.username}."
  puts "You have the right to #{@user.permission} on/to Flickr."

  @flickr_user = flickr.people.findByUsername(:username => login.username)
  @flickr_user_id = @flickr_user.nsid
end

# ############## #
#     METHODS    #
# ############## #

def photo_upload
  begin
    @photo.description = @album.name
    @photo.id = upload_to_flickr
    print blue, "Uploaded #{@photo.title} to Flickr.\n", reset
  rescue => e
    print red, "FAILED to upload #{@photo.full_path}.\n"
    print "\t#{e.message}\n", reset
    @upload.failed_uploads << @photo.full_path
  end
end

def upload_to_flickr
  flickr.upload_photo(@photo.full_path,
                      :title => @photo.title,
                      :description => @photo.description,
                      :is_public => @photo.public,
                      :is_family => @photo.family,
                      :is_friend => @photo.friend)
end

def create_flickr_set
  begin
    photoset = flickr.photosets.create(:title => @album.name,
                                       :description => @album.description,
                                       :primary_photo_id => @photo.id)
    @album.id = photoset.id
    print blue, "Created photo album with title #{@album.name}.\n", reset
  rescue => e
    print red, "FAILED to create photo album #{@album.name}.\n"
    print "\t#{e.message}\n", reset
  end
end

def add_to_flickr_set
  begin
    flickr.photosets.addPhoto(:photoset_id => @album.id, :photo_id => @photo.id)
    print blue, "Added #{@photo.title} to #{@album.name}.\n", reset
  rescue => e
    print red, "FAILED to add #{@photo.full_path} to album #{@album.name}.\n"
    print "\t#{e.message}\n", reset
  end
end

def get_user_albums
  begin
    flickr.photosets.getList(:user_id => @flickr_user_id)
  rescue => e
    print red, "FAILED to get all albums for user #{@user.name}.\n"
    print "\t#{e.message}\n", reset
  end
end

def get_album_name(path)
  @album.name = path.gsub(/\/$/, '').split("/")[-1]
end

def get_album_index
  index = nil
  @upload.existing_albums.each_with_index do |e_album, i|
    index = i if e_album.title == @album.name
  end
  index
end

def existing_album(index)
  e_album = @upload.existing_albums[index]
  @upload.skipped_dirs << @path   if @upload.behavior == :skip_album
  @album.id = e_album.id.to_i     if @upload.behavior == :add_to_album
end

# ######### #
#  PROGRAM  #
# ######### #

def start_program
  set_path
  set_user
  login

  path = @options[:path]
  source_path = (path.empty? || path.match(/\/$/)) ? path : path + "/"

  @upload = Upload.new(source_path)

  @sub_directories =  Dir.glob(@upload.source_path + "**/")
  set_upload_behavior

  @upload.existing_albums = get_user_albums
end

def start_upload_to_flickr
  start_program

  @sub_directories.each do |path|
    # @path = path
    @album = Album.new
    get_album_name(path)
    images = []
    IMAGE_TYPES.each do  |type|
      images += Dir["#{path}*.#{type}"]
    end
    if images.length > 0
      puts "================================================="
      print bold, "  Processing directory #{path}\n", reset
      puts "================================================="
      puts "Files in directory: #{images.length}"
      puts
    end

    index = get_album_index
    existing_album(index) if index

    unless @upload.behavior == :skip_album && index
      images.each do |image|
        if image.match(IMAGE_MATCHER)
          @photo = Image.new
          @photo.title = File.basename(image).gsub(IMAGE_MATCHER, '')
          @photo.full_path = image
          photo_upload
          (images[0] == @photo.full_path && @album.id.nil?) ? create_flickr_set : add_to_flickr_set
        end
      end
    end
  end

  @upload.summarize_failed_uploads
  @upload.summarize_skipped_directories
end

start_upload_to_flickr
