class Download
  attr_accessor :target_directory, :source_directory, :in_same_album, :album_id, :photo_ids, :album_title, :directory, :total

  def initialize
    @target_directory = nil
    @source_directory = nil
    @in_same_album = false
    @album_id = nil
    @photo_ids = []
    @album_title = nil
    @directory = nil
    @total = 0
  end
end