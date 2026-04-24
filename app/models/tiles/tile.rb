module Tiles
  class Tile
    BUILDABLE_TERRAIN = %w[C D F G T].freeze

    attr_accessor :qty

    def initialize(qty)
      @qty = qty
    end

    def tile_css_class
      self.class.name.demodulize.delete_suffix("Tile").downcase
    end

    def description
      "#{self.class.name.demodulize.delete_suffix("Tile")} - #{self.class::DESCRIPTION}"
    end

    def build_terrain = nil

    def valid_destinations(from_row: nil, from_col: nil, board_contents:, board:, player_order:, hand: nil, supply: Hash.new(0))
      terrain = build_terrain || hand
      return [] unless terrain

      settlements = board_contents.settlements_for(player_order)
      settlements = settlements.reject { |r, c| r == from_row && c == from_col } if from_row && from_col

      adjacent = settlements.flat_map do |r, c|
        board_contents.neighbors_where(r, c) do |nr, nc|
          board_contents.available_for_building?(nr, nc) && board.terrain_at(nr, nc) == terrain
        end
      end.uniq

      return adjacent unless adjacent.empty?

      (0..19).flat_map do |r|
        (0..19).filter_map do |c|
          [ r, c ] if board_contents.available_for_building?(r, c) && board.terrain_at(r, c) == terrain
        end
      end
    end

    def selectable_settlements(player_order:, board_contents:, board:, hand: nil, supply: Hash.new(0))
      return [] unless moves_settlement?
      return [] unless valid_destinations(board_contents:, board:, player_order:, hand:).any?
      board_contents.settlements_for(player_order)
    end

    def activatable?(player_order:, board_contents:, board:, hand: nil, supply: Hash.new(0))
      valid_destinations(board_contents:, board:, player_order:, hand:).any?
    end

    def builds_settlement?
      false
    end

    def moves_settlement?
      false
    end

    def nomad_tile?
      false
    end

    def places_wall?
      false
    end

    def places_meeple?
      false
    end

    def meeple_kind = nil

    def on_pickup(game_player:)
      nil
    end

    def outpost_tile?
      false
    end

    def sword_tile?
      false
    end

    # Returns the terrain key that constrains the move destination, or nil if unconstrained.
    # Subclasses override this (e.g. BarnTile returns hand, HarborTile returns "W").
    def move_terrain(hand:) = nil

    # Human-readable description of what the player must do with this tile.
    def action_message(player_handle:, terrain_names:, hand: nil)
      if moves_settlement?
        terrain = move_terrain(hand:)
        msg = "#{player_handle} must move a settlement"
        terrain ? "#{msg} to a #{terrain_names[terrain]} space" : msg
      else
        terrain = build_terrain || hand
        terrain ? "#{player_handle} must build on a #{terrain_names[terrain]} space" : "#{player_handle} must build"
      end
    end

    def self.for_klass(name)
      "Tiles::#{name}".safe_constantize || Boards::Board::TILE_CLASSES[name]
    end

    def self.from_hash(hash)
      tile_class = for_klass(hash["klass"])
      raise ArgumentError, "Unknown tile class: #{hash['klass']}" unless tile_class
      tile_class.new(0)
    end
  end
end
