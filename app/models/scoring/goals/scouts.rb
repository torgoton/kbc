class Scoring
  module Goals
    class Scouts < Goal
      DESCRIPTION = "1 point for each settlement next to, but not on, the terrain removed from the deck."
      def score_for(game_player)
        terrain = @game.removed_terrain
        { score: terrain ? count_adjacent_to(game_player.order, terrain) : 0 }
      end
    end
  end
end
