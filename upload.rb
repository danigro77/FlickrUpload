require 'term/ansicolor'

class Upload

  include Term::ANSIColor

  VALID_BEHAVIOR = [:new_album, :skip_album, :add_to_album]

  attr_accessor :skipped_dirs, :failed_uploads, :source_path, :existing_albums, :behavior

  def initialize(source_path)
    @skipped_dirs = []
    @failed_uploads = []
    @behavior = :new_album
    @source_path = source_path
    @existing_albums = []
  end

  def valid_behavior?
    VALID_BEHAVIOR.include?(self.behavior)
  end

  def summarize_failed_uploads
    if self.failed_uploads.empty?
      puts
      print green, bold, "DONE UPLOADING ALL IMAGES\n", reset
      puts
    else
      puts
      puts red, bold, "================================================="
      puts "================ NOT UPLOADED: =================="
      puts "=================================================", reset
      puts self.failed_uploads
      puts
    end
  end

  def summarize_skipped_directories
    if self.skipped_dirs.empty?
      print green, bold, "NO DIRECTORIES WERE SKIPPED\n", reset
      puts
    else
      puts red, bold, "================================================="
      puts "============= SKIPPED DIRECTORIES: =============="
      puts "=================================================", reset
      puts self.skipped_dirs
      puts
    end
  end
end