require 'term/ansicolor'

class Upload

  include Term::ANSIColor

  VALID_BEHAVIOR = [:new_album, :skip_album, :add_to_album]

  attr_accessor :skipped_dirs, :failed_uploads, :not_in_album, :source_path, :existing_albums, :behavior

  def initialize(source_path)
    @skipped_dirs = []
    @failed_uploads = []
    @not_in_album = {}
    @behavior = :new_album
    @source_path = source_path
    @existing_albums = []
  end

  def valid_behavior?
    VALID_BEHAVIOR.include?(self.behavior)
  end

  def summarize_failed_uploads
    if self.failed_uploads.empty?
      puts green, bold, "DONE UPLOADING ALL IMAGES", reset
    else
      failed_message('not uploaded', self.failed_uploads)
    end
  end

  def summarize_skipped_directories
    if self.skipped_dirs.empty?
      puts green, bold, "NO DIRECTORIES WERE SKIPPED", reset
    else
      failed_message('skipped directories', self.skipped_dirs)
    end
  end

  def summarize_not_in_album
    if self.not_in_album.empty?
      puts green, bold, "ALL IMAGES IN ALBUMS", reset
    else
      failed_message('not in directory', self.not_in_album, true)
    end
  end

  def failed_message(msg, data, hashed_data=nil)
    puts red, bold, "#{msg.upcase}:", reset
    if hashed_data
      data.each_pair do |dir, img|
        img.each do |i|
          puts "#{dir}: #{i}"
        end
        puts
      end
    else
      puts data
    end
  end
end