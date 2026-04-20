class Scoring
  class Scorer
    AREA_TERRAINS = %w[C D F G T W M].freeze

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
        board.terrain_at(r, c) != terrain &&
          neighbors(r, c).any? { |nr, nc| board.terrain_at(nr, nc) == terrain }
      end
    end

    def castle_hexes
      @castle_hexes ||= board.map.each_with_index.flat_map do |section, i|
        section.silver_hexes
               .select { |h| h[:k] == "Castle" }
               .map { |h| [ i / 2 * 10 + h[:r], i % 2 * 10 + h[:c] ] }
      end
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
        20.times.filter_map { |c| [ r, c ] if board.terrain_at(r, c) == terrain }
      end
    end
  end
end
