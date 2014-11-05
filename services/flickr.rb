require 'term/ansicolor'

require_relative 'user.rb'
require_relative 'image.rb'
require_relative 'album.rb'
require_relative 'download_photo.rb'

class Flickr

  include Term::ANSIColor

  MAX_RETRIES = 3

  def self.connect_with(user)
    begin
      FlickRaw.api_key = user.api_key
      FlickRaw.shared_secret = user.shared_secret
    rescue => e
      error_message("FAILED to connect #{user.name} with Flickr.", e.message)
      puts "\tAPI KEY: #{user.api_key}"
      puts "\tSHARED SECRET: #{user.shared_secret}"
    end
  end

  def self.authenticate(user)
    begin
      flickr.access_token = user.access_token
      flickr.access_secret = user.access_secret
    rescue => e
      error_message("FAILED to authenticate #{user.name}.", e.message)
    end

    @login = flickr.test.login
    puts "You are now authenticated as #{@login.username}."
    case user.permission
      when 'read'
        puts "You have the right to >>read<< on Flickr."
      when 'write'
        puts "You have the right to >>read and write<< on Flickr."
      else
        puts "You have the right to >>read, write and delete<< on Flickr."
    end
  end

  def self.get_auth_keys(user)
    begin
      token = flickr.get_request_token
      auth_url = flickr.get_authorize_url(token['oauth_token'], :perms => user.permission)
    rescue => e
      error_message("FAILED to get authentication keys!", e.message)
    end

    puts "Open this url in your process to complete the authentication process:"
    puts "#{auth_url}"
    puts "Copy here the number given when you complete the process."
    verify = gets.strip

    begin
      flickr.get_access_token(token['oauth_token'], token['oauth_token_secret'], verify)
      @login = flickr.test.login
      puts "You are now authenticated as #{@login.username} and have the right to #{user.permission} on/to Flickr."
    rescue FlickRaw::FailedResponse => e
      error_message("FAILED to authenticate!", e.message)
    end
    {:token => flickr.access_token, :secret => flickr.access_secret}
  end

  def self.get_user
    flickr.people.findByUsername(:username => @login.username)
  end

  def self.do_upload(photo)
    @counter ||= 0
    begin
      flickr.upload_photo(photo.full_path,
                        :title        => photo.title,
                        :description  => photo.description,
                        :is_public    => photo.public,
                        :is_family    => photo.family,
                        :is_friend    => photo.friend)
    rescue Net::ReadTimeout => e
      if @counter < MAX_RETRIES
        do_upload(photo)
        @counter += 1
      else
        @counter = 0
        error_message("FAILED to upload photo #{photo.full_path} after 3 retries.", e.message)
      end
    rescue => e
      error_message("FAILED to upload photo #{photo.full_path}.", e.message)
      nil
    end
  end

  def self.create_album(album, photo_id)
    begin
      result = flickr.photosets.create(:title => album.name,
                            :description => album.description,
                            :primary_photo_id => photo_id)
      result.id
    rescue => e
      error_message("FAILED to create photo album #{album.name}.", e.message)
      nil
    end
  end

  def self.add_to_album(album, photo_id, path)
    begin
      flickr.photosets.addPhoto(:photoset_id => album.flickr_id, :photo_id => photo_id)
    rescue => e
      error_message("FAILED to add photo #{path} to album #{album.name}.", e.message)
      nil
    end
  end

  def self.get_user_albums(user_id, user)
    begin
      flickr.photosets.getList(:user_id => user_id)
    rescue => e
      error_message("FAILED to get all albums for user #{user.name}.", e.message)
    end
  end

  def self.get_photos_in_album(download)
    photos = []
    begin
      album = flickr.photosets.getPhotos(:photoset_id => download.album_id)
      album['photo'].each do |img|
        photos << img['id']
      end
    rescue => e
      error_message("FAILED to get the photos of the album #{download.source_directory}.", e.message)
    end
    photos
  end

  def self.get_photo_url(image, size)
    begin
      image_in_all_sizes = flickr.photos.getSizes(:photo_id => image.flickr_id)
      image_in_all_sizes.each do |image_in_one_size|
        if size == image_in_one_size['label']
          image.size = image_in_one_size['label']
          image.source = image_in_one_size['source']
          # image.title = image.get_title_from_source
        end
      end
      image
    rescue => e
      error_message("FAILED to get the URL for image with the Flickr ID #{image.flickr_id}.", e.message)
      nil
    end
  end

  def self.error_message(text, msg)
    print red, "#{text}.\n"
    print "\t#{msg}\n", reset
  end

  # FOR DEBUG

  def self.get_album(id)
    p flickr.photosets.getInfo(:photoset_id => id)
  end
end