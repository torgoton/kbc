class Scoring
  class Scorer
    AREA_TERRAINS = %w[C D F G T W M B].freeze

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

    def count_adjacent_to(order, terrain)
      settlements_for(order).count do |r, c|
        board_contents.terrain_at(r, c) != terrain &&
          neighbors(r, c).any? { |nr, nc| board_contents.terrain_at(nr, nc) == terrain }
      end
    end

    def castle_hexes = silver_hexes_of("Castle")

    def silver_hexes_of(kind)
      @silver_hexes_of ||= {}
      @silver_hexes_of[kind] ||= board.map.each_with_index.flat_map do |section, i|
        section.silver_hexes
               .select { |h| h[:k] == kind }
               .map { |h| [ i / 2 * 10 + h[:r], i % 2 * 10 + h[:c] ] }
      end
    end

    # 5 points for each of +hexes+ where the player has the most adjacent settlements (ties score for all tied).
    def majority_hexes_score(game_player, hexes)
      orders = @game.game_players.map(&:order)
      scored = hexes.count do |r, c|
        counts = orders.to_h { |o| [ o, neighbors(r, c).count { |n| board_contents.player_at(*n) == o } ] }
        counts[game_player.order].positive? && counts[game_player.order] == counts.values.max
      end
      scored * 5
    end

    def connected_components(order)
      remaining = settlements_for(order).to_set
      components = []
      until remaining.empty?
        start = remaining.first
        component = []
        queue = [ start ]
        remaining.delete(start)
        until queue.empty?
          pos = queue.shift
          component << pos
          neighbors(*pos).each do |n|
            next unless remaining.include?(n)
            remaining.delete(n)
            queue << n
          end
        end
        components << component
      end
      components
    end

    def terrain_components_for(terrain)
      @terrain_components ||= {}
      @terrain_components[terrain] ||= begin
        remaining = terrain_hexes(terrain).to_set
        components = []
        until remaining.empty?
          start = remaining.first
          component = []
          queue = [ start ]
          remaining.delete(start)
          until queue.empty?
            pos = queue.shift
            component << pos
            neighbors(*pos).each do |n|
              next unless remaining.include?(n)
              remaining.delete(n)
              queue << n
            end
          end
          components << component
        end
        components
      end
    end

    def terrain_hexes(terrain)
      @terrain_hexes ||= {}
      @terrain_hexes[terrain] ||= 20.times.flat_map do |r|
        20.times.filter_map { |c| [ r, c ] if board_contents.terrain_at(r, c) == terrain }
      end
    end
  end
end
