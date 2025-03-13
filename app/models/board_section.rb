class BoardSection
  attr_accessor :terrain
  attr_accessor :content

  def initialize
    @terrain = []
    @content = []
  end

  def terrain_at(row, column)
    @terrain[row][column]
  end
end
