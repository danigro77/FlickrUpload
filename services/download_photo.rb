class DownloadPhoto
  attr_accessor :size, :source, :flickr_id, :title, :type

  def initialize(flickr_id)
    @size = nil
    @source = nil
    @flickr_id = flickr_id
    @title = nil
    @type = nil
  end

  def get_type_from_source
    self.source.split('.').last
  end

end