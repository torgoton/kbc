class Scoring
  class Goal
    def initialize(game)
      @game = game
    end

    def score_for(_game_player)
      raise NotImplementedError, "#{self.class} must implement score_for"
    end

    private

    def board = @game.board
    def board_contents = @game.board_contents
    def settlements_for(order) = board_contents.settlements_for(order)
    def neighbors(r, c) = board_contents.neighbors(r, c)

    def castle_hexes
      @castle_hexes ||= @game.board.map.each_with_index.flat_map do |section, i|
        section.scoring_hexes.map { |h| [ i / 2 * 10 + h[:r], i % 2 * 10 + h[:c] ] }
      end
    end
  end
end
