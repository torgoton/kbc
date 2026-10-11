module Tiles
  class Tile
    def creator = "override".freeze
    def class_description = "override".freeze

    def tile_description
      self.class.const_defined?(:DESCRIPTION) ? self.class::DESCRIPTION : "should be overridden"
    end

    BUILDABLE_TERRAIN = %w[C D F G T B].freeze
    CATEGORIES = %w[permanent location nomad bonus].freeze

    attr_accessor :qty

    def initialize(qty)
      @qty = qty
    end

    def tile_css_class
      self.class.name.demodulize.delete_suffix("Tile").downcase
    end

    def tile_category
      return "permanent" if is_a?(Tiles::Permanent)
      return "location" if is_a?(Tiles::Location)
      return "nomad" if is_a?(Tiles::Nomad)
      "bonus" if is_a?(Tiles::Bonus)
    end

    def description
      "#{self.class.name.demodulize.delete_suffix("Tile")}<br>" \
      "#{self.tile_description}<br><br>" \
      "#{self.class_description}<br>"
    end

    def build_terrain = nil

    # Fixed set of terrains a tile may build on (Canoe Bonus), else nil.
    def build_terrains = nil

    # The holder's tiles, so a tile can check for the Bonus tile that modifies it.
    def with_player(game_player)
      @player_tiles = game_player&.tiles
      self
    end

    # An unused (i.e. not acquired this turn) Bonus tile of this klass in the holder's tiles.
    def bonus_active?(klass)
      (@player_tiles || []).any? { |t| t["klass"] == klass && !t["used"] }
    end

    # Klass of the Bonus tile awarded with the 2nd copy of this tile, if it has one.
    def bonus_tile_klass = nil

    def valid_destinations(from_row: nil, from_col: nil, board_contents:, player_order:, hand: nil, supply: Hash.new(0), budget: nil)
      terrain = build_terrain || hand
      return [] unless terrain

      excluding = (from_row && from_col) ? [ from_row, from_col ] : nil
      board_contents.buildable_cells_for(player_order, terrain, excluding: excluding)
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

    # Temple: take one of your settlements off the board to build next turn.
    # Canoe: a reaction to a location being emptied.
    def canoe_tile?
      false
    end

    def sets_aside_settlement?
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
        terrain ? "#{msg} to a #{terrain_names[terrain]} hex" : msg
      else
        terrain = build_terrain || hand
        terrain ? "#{player_handle} must build on a #{terrain_names[terrain]} hex" : "#{player_handle} must build"
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
