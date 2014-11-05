class DownloadControl

  attr_accessor :downloads, :source_directories, :skipped_albums, :sizes, :all_albums, :failed_downloads

  def initialize
    @downloads = []
    @source_directories = []
    @skipped_albums = []
    @sizes = ['Original']
    @all_albums = []
    @failed_downloads = {}
  end
end