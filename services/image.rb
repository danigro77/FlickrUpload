class Image

  attr_accessor :full_path, :id, :title, :description, :public, :family, :friend

  def initialize
    @path = nil
    @id = nil
    @title = nil
    @description = nil
    @public = 0
    @family = 0
    @friend = 0
  end
end