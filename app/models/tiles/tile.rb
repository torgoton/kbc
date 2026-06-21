module Tiles
  class Tile
    def creator = "".freeze
    def class_description = "should be overridden".freeze
    def tile_description = "should be overridden".freeze

    BUILDABLE_TERRAIN = %w[C D F G T].freeze

    attr_accessor :qty

    def initialize(qty)
      @qty = qty
    end

    def tile_css_class
      self.class.name.demodulize.delete_suffix("Tile").downcase
    end

    def description
      "#{self.class.name.demodulize.delete_suffix("Tile")}<br>" \
      "#{self.class_description}<br>" \
      "#{self.tile_description}"
    end

    def build_terrain = nil

    def valid_destinations(from_row: nil, from_col: nil, board_contents:, player_order:, hand: nil, supply: Hash.new(0), budget: nil)
      terrain = build_terrain || hand
      return [] unless terrain

      settlements = board_contents.settlements_for(player_order)
      settlements = settlements.reject { |r, c| r == from_row && c == from_col } if from_row && from_col

      adjacent = settlements.flat_map do |r, c|
        board_contents.neighbors_where(r, c) do |nr, nc|
          board_contents.available_for_building?(nr, nc) && board_contents.terrain_at(nr, nc) == terrain
        end
      end.uniq

      return adjacent unless adjacent.empty?

      (0..19).flat_map do |r|
        (0..19).filter_map do |c|
          [ r, c ] if board_contents.available_for_building?(r, c) && board_contents.terrain_at(r, c) == terrain
        end
      end
    end

    def selectable_settlements(player_order:, board_contents:, hand: nil, supply: Hash.new(0), budget: nil)
      return [] unless moves_settlement?
      return [] unless valid_destinations(board_contents:, player_order:, hand:).any?
      board_contents.settlements_for(player_order).reject { |r, c| board_contents.city_hall_at?(r, c) }
    end

    def activatable?(player_order:, board_contents:, hand: nil, supply: Hash.new(0))
      valid_destinations(board_contents:, player_order:, hand:).any?
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

    def places_city_hall?
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

    def fort_tile?
      false
    end

    # Settlement movement with a per-turn budget (ResettlementTile), as opposed
    # to the single-step movers handled by SettlementMovePhase.
    def resettles?
      false
    end

    # Grants more than one settlement build in a row (DonationTile); build_quota
    # is how many.
    def repeats_build?
      false
    end

    def build_quota
      1
    end

    # A nomad tile that is consumed for points the instant it is picked up
    # returns [goal, points] here (TreasureTile); tiles that are instead held
    # with an expiry return nil.
    def pickup_score
      nil
    end

    def crossroads_tile?
      false
    end

    def uses_played_terrain?
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
