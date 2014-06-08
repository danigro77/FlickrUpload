require 'flickraw'
require 'optparse'
require "yaml"
require 'term/ansicolor'

require_relative 'services/user.rb'
require_relative 'services/upload.rb'
require_relative 'services/image.rb'
require_relative 'services/album.rb'
require_relative 'services/flickr.rb'

include Term::ANSIColor

IMAGE_TYPES = %w(jpeg JPEG jpg JPG png PNG gif GIF tiff TIFF mpeg MPEG mp4 MP4 avi AVI wmv WMV mov MOV mpg MPG mp1 MP1 mp2 MP2 mpv MPV 3gp 3GP m2ts M2TS ogg OGG ogv OGV )
IMAGE_MATCHER = /\.(jpe?g|gif|png|tiff|mpe?g|mp4|avi|wmv|mov|mp1|mp2|mpv|3gp|m2ts|ogg|ogv)$/i

@options = {}

opt_parse = OptionParser.new do |opts|
  opts.banner = "Usage: upload_to_flickr.rb [options]"

  opts.on('-u', '--user USER', 'Input your Flickr user name') do |u|
    @options[:user] = u
  end

  opts.on('-p', '--path PATH', 'Input the full source path') do |p|
    @options[:path] = p
  end

  opts.on('-m', '--mode MODE', 'Set upload mode [n/new, s/skip, a/add] for behavior when album exists') do |m|
    @options[:mode] = m
  end

  opts.on( '-h', '--help', 'Display help screen' ) do
    puts opts
    exit
  end
end

opt_parse.parse!

# ################ #
#  ENSURE OPTIONS  #
# ################ #

def set_path
  if @options[:path]
    path = @options[:path]
    @source_path = (path.empty? || path.match(/\/$/)) ? path : path + "/"
  else
    puts bold, "No path entered!", reset
    puts "-p/--path /full/path/to/source/directory"
    exit
  end
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

def set_upload_behavior
  if @options[:mode]
    case @options[:mode]
      when 'n' || 'new'   then @upload.behavior =  :new_album
      when 's' || 'skip'  then @upload.behavior =  :skip_album
      when 'a' || 'add'   then @upload.behavior =  :add_to_album
      else
        puts bold, "Unknown behavior, you entered: " + @options[:mode] + "!", reset
        behavior_help
        exit
    end
  else
    puts bold, "No behavior entered!", reset
    behavior_help
    exit
  end
end

def behavior_help
  puts "-m/--mode n, new = create new album with same name"
  puts "-m/--mode s, skip = skip album if it has same name as an existing one"
  puts "-m/--mode a, add = add all photos to existing album"
end


# ############## #
#     METHODS    #
# ############## #

def login
  Flickr.connect_with(@user)
  Flickr.authenticate(@user)
  @flickr_user = Flickr.get_user
  @flickr_user_id = @flickr_user.nsid
end

def create_album(path)
  @album = Album.new
  @album.name = path.gsub(/\/$/, '').split("/")[-1]
end

def get_album_index
  index = nil
  @upload.existing_albums.each_with_index do |e_album, i|
    index = i if e_album.title == @album.name
  end
  index
end

def directory_info
  print bold, "  Processing directory #{@dir_path}\n", reset
  puts "\t\tFiles in directory: #{@images.length}"
  puts
end

def existing_album(index)
  e_album = @upload.existing_albums[index]
  @upload.skipped_dirs << @dir_path   if skip_album?
  @album.flickr_id = e_album.id.to_i  if @upload.behavior == :add_to_album
end

def new_album?
  @images[0] == @photo.full_path && @album.flickr_id.nil?
end

def skip_album?
  @upload.behavior == :skip_album
end

def collect_images
  @images = []
  IMAGE_TYPES.each do  |type|
    @images += Dir["#{@dir_path}*.#{type}"]
  end
end

def new_image(image)
  @photo = Image.new
  @photo.title = File.basename(image).gsub(IMAGE_MATCHER, '')
  @photo.full_path = image
  @photo.description = @album.name
end

def upload_images
  @images.each do |image|
    if image.match(IMAGE_MATCHER)
      new_image(image)
      handle_image_upload
    end
  end
end

def init_program
  set_path
  set_user

  login

  @upload = Upload.new(@source_path)
  set_upload_behavior

  @sub_directories =  Dir.glob(@upload.source_path + "**/")

  @upload.existing_albums = Flickr.get_user_albums(@flickr_user_id, @user)
end

def handle_image_upload
  photo_id = Flickr.do_upload(@photo)
  if photo_id.nil?
    @upload.failed_uploads << @photo.full_path
  elsif new_album?
    @album.flickr_id = Flickr.create_album(@album, photo_id)
  else
    added = Flickr.add_to_album(@album, photo_id, @photo.full_path)
    unless added
      @upload.not_in_album[@album.name] ||= []
      @upload.not_in_album[@album.name] << @photo.full_path
    end
  end
end

def handle_directory
  create_album(@dir_path)
  collect_images

  directory_info if @images.length > 0

  index = get_album_index
  existing_album(index) if index

  upload_images unless skip_album? && index
end

# ############# #
#  RUN PROGRAM  #
# ############# #

def start_upload_to_flickr
  init_program

  @sub_directories.each do |path|
    @dir_path = path
    handle_directory
  end

  @upload.summarize_failed_uploads
  @upload.summarize_skipped_directories if skip_album?
  @upload.summarize_not_in_album
end

start_upload_to_flickr
