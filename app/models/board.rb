class Board
  def initialize(game_board)
    @board_objects = []
    game_board.each do |section|
      @board_objects << "#{section[0]}Board".constantize.new(section[1])
    end
  end

  def terrain_at(row, column)
    section = 2 * (row / 10) + column / 10
    @board_objects[section].terrain_at(row % 10, column % 10)
  end
end
