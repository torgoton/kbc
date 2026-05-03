class TurnPhase
  class InvalidTransition < StandardError; end

  TransitionResult = Struct.new(
    :next_phase,
    :terrain_lock,
    :action_completed,
    :source_cleared,
    keyword_init: true
  )

  module Events
    BuildChosen = Struct.new(:coordinate, keyword_init: true)
    TileActionSelected = Struct.new(keyword_init: true)
    SourceSelected = Struct.new(:coordinate_key, keyword_init: true)
    DestinationChosen = Struct.new(keyword_init: true)
  end

  module Facts
    BuildChoice = Struct.new(:locked_terrain, keyword_init: true)
    TileActionSelection = Struct.new(:selected_phase, keyword_init: true)
    DestinationChoice = Struct.new(:next_phase, keyword_init: true)
  end

  def self.deserialize(data)
    hash = (data || { "type" => "mandatory" }).deep_stringify_keys
    type = hash["type"] || "mandatory"

    return MandatoryBuildPhase.from_hash(hash) if type == "mandatory"

    klass_name = hash["klass"] || "#{type.capitalize}Tile"
    tile_class = Tiles::Tile.for_klass(klass_name)
    tile = tile_class&.new(0)

    if tile&.fort_tile?
      FortPhase.from_hash(hash)
    elsif tile&.is_a?(Tiles::Nomad::ResettlementTile)
      ResettlementPhase.from_hash(hash)
    elsif tile && (tile.builds_settlement? || tile.places_wall?)
      TileBuildPhase.from_hash(hash)
    elsif tile&.sword_tile?
      TargetedRemovalPhase.from_hash(hash)
    elsif tile && tile.places_meeple? && tile.meeple_kind == "warrior"
      MeepleActionPhase.from_hash(hash)
    elsif tile&.places_city_hall?
      CityHallPhase.from_hash(hash)
    elsif tile && tile.places_meeple? && %w[ship wagon].include?(tile.meeple_kind)
      MeepleMovementPhase.from_hash(hash)
    elsif tile && tile.moves_settlement?
      SettlementMovePhase.from_hash(hash)
    else
      LegacyPhase.new(hash)
    end
  end

  def type
    serialize.fetch("type")
  end

  def klass_name
    serialize["klass"]
  end

  def chosen_terrain
    serialize["chosen_terrain"]
  end

  def from
    serialize["from"]
  end

  def transition(_event, _facts)
    raise InvalidTransition, "#{self.class.name} does not accept that event"
  end
end

class TurnPhase::MandatoryBuildPhase < TurnPhase
  attr_reader :chosen_terrain_value, :builds, :outpost_active_value

  def self.from_hash(hash)
    new(
      chosen_terrain: hash["chosen_terrain"],
      builds: Array(hash["builds"]),
      outpost_active: hash["outpost_active"] == true
    )
  end

  def initialize(chosen_terrain: nil, builds: [], outpost_active: false)
    @chosen_terrain_value = chosen_terrain
    @builds = builds
    @outpost_active_value = outpost_active
  end

  def chosen_terrain
    @chosen_terrain_value
  end

  def outpost_active?
    outpost_active_value == true
  end

  def transition(event, facts)
    case event
    when TurnPhase::Events::BuildChosen
      next_terrain = chosen_terrain || facts.locked_terrain
      TurnPhase::TransitionResult.new(
        next_phase: self.class.new(
          chosen_terrain: next_terrain,
          builds: builds + [ event.coordinate ],
          outpost_active: outpost_active?
        ),
        terrain_lock: next_terrain
      )
    when TurnPhase::Events::TileActionSelected
      TurnPhase::TransitionResult.new(
        next_phase: facts.selected_phase,
        action_completed: false,
        source_cleared: true
      )
    else
      super
    end
  end

  def serialize
    hash = { "type" => "mandatory" }
    hash["chosen_terrain"] = chosen_terrain if chosen_terrain
    hash["builds"] = builds if builds.any?
    hash["outpost_active"] = true if outpost_active?
    hash
  end
end

class TurnPhase::TileBuildPhase < TurnPhase
  attr_reader :action_type, :klass_value, :chosen_terrain_value, :remaining, :walls_placed

  def self.from_hash(hash)
    new(
      action_type: hash.fetch("type"),
      klass_name: hash["klass"],
      chosen_terrain: hash["chosen_terrain"],
      remaining: hash["remaining"],
      walls_placed: hash["walls_placed"]
    )
  end

  def initialize(action_type:, klass_name:, chosen_terrain: nil, remaining: nil, walls_placed: nil)
    @action_type = action_type
    @klass_value = klass_name
    @chosen_terrain_value = chosen_terrain
    @remaining = remaining
    @walls_placed = walls_placed
  end

  def type
    action_type
  end

  def klass_name
    klass_value
  end

  def chosen_terrain
    chosen_terrain_value
  end

  def decrement_remaining
    self.class.new(
      action_type: action_type,
      klass_name: klass_name,
      chosen_terrain: chosen_terrain,
      remaining: remaining && remaining - 1,
      walls_placed: walls_placed
    )
  end

  def increment_walls_placed
    self.class.new(
      action_type: action_type,
      klass_name: klass_name,
      chosen_terrain: chosen_terrain,
      remaining: remaining,
      walls_placed: walls_placed.to_i + 1
    )
  end

  def serialize
    hash = { "type" => action_type }
    hash["klass"] = klass_name if klass_name
    hash["chosen_terrain"] = chosen_terrain if chosen_terrain
    hash["remaining"] = remaining if remaining
    hash["walls_placed"] = walls_placed if walls_placed
    hash
  end
end

class TurnPhase::FortPhase < TurnPhase
  attr_reader :fort_terrain_value

  def self.from_hash(hash)
    new(fort_terrain: hash.fetch("fort_terrain"))
  end

  def initialize(fort_terrain:)
    @fort_terrain_value = fort_terrain
  end

  def type
    "fort"
  end

  def klass_name
    "FortTile"
  end

  def fort_terrain
    fort_terrain_value
  end

  def serialize
    {
      "type" => "fort",
      "klass" => "FortTile",
      "fort_terrain" => fort_terrain
    }
  end
end

class TurnPhase::SettlementMovePhase < TurnPhase
  attr_reader :action_type, :klass_value, :from_value

  def self.from_hash(hash)
    new(
      action_type: hash.fetch("type"),
      klass_name: hash["klass"],
      from: hash["from"]
    )
  end

  def initialize(action_type:, klass_name:, from: nil)
    @action_type = action_type
    @klass_value = klass_name
    @from_value = from
  end

  def type
    action_type
  end

  def klass_name
    klass_value
  end

  def from
    from_value
  end

  def transition(event, facts)
    case event
    when TurnPhase::Events::SourceSelected
      TurnPhase::TransitionResult.new(
        next_phase: self.class.new(
          action_type: action_type,
          klass_name: klass_name,
          from: event.coordinate_key
        ),
        source_cleared: false
      )
    when TurnPhase::Events::DestinationChosen
      TurnPhase::TransitionResult.new(
        next_phase: facts.next_phase,
        action_completed: true,
        source_cleared: true
      )
    else
      super
    end
  end

  def serialize
    hash = { "type" => action_type }
    hash["klass"] = klass_name if klass_name
    hash["from"] = from if from
    hash
  end
end

class TurnPhase::ResettlementPhase < TurnPhase
  attr_reader :budget_value, :vacated_value, :moves_value, :from_value

  def self.from_hash(hash)
    new(
      budget: hash.fetch("budget"),
      vacated: Array(hash["vacated"]),
      moves: hash.fetch("moves"),
      from: hash["from"]
    )
  end

  def initialize(budget:, vacated:, moves:, from: nil)
    @budget_value = budget
    @vacated_value = vacated
    @moves_value = moves
    @from_value = from
  end

  def type
    "resettlement"
  end

  def klass_name
    "ResettlementTile"
  end

  def budget
    budget_value
  end

  def vacated
    vacated_value
  end

  def moves
    moves_value
  end

  def from
    from_value
  end

  def transition(event, facts)
    case event
    when TurnPhase::Events::SourceSelected
      TurnPhase::TransitionResult.new(
        next_phase: self.class.new(
          budget: budget,
          vacated: vacated,
          moves: moves,
          from: event.coordinate_key
        ),
        source_cleared: false
      )
    when TurnPhase::Events::DestinationChosen
      TurnPhase::TransitionResult.new(
        next_phase: facts.next_phase,
        action_completed: facts.next_phase.is_a?(TurnPhase::MandatoryBuildPhase),
        source_cleared: true
      )
    else
      super
    end
  end

  def serialize
    hash = {
      "type" => "resettlement",
      "klass" => "ResettlementTile",
      "budget" => budget,
      "vacated" => vacated,
      "moves" => moves
    }
    hash["from"] = from if from
    hash
  end
end

class TurnPhase::MeepleMovementPhase < TurnPhase
  attr_reader :action_type, :klass_value, :from_value

  def self.from_hash(hash)
    new(
      action_type: hash.fetch("type"),
      klass_name: hash["klass"],
      from: hash["from"]
    )
  end

  def initialize(action_type:, klass_name:, from: nil)
    @action_type = action_type
    @klass_value = klass_name
    @from_value = from
  end

  def type
    action_type
  end

  def klass_name
    klass_value
  end

  def from
    from_value
  end

  def transition(event, facts)
    case event
    when TurnPhase::Events::SourceSelected
      TurnPhase::TransitionResult.new(
        next_phase: self.class.new(
          action_type: action_type,
          klass_name: klass_name,
          from: event.coordinate_key
        ),
        source_cleared: false
      )
    when TurnPhase::Events::DestinationChosen
      TurnPhase::TransitionResult.new(
        next_phase: facts.next_phase,
        action_completed: true,
        source_cleared: true
      )
    else
      super
    end
  end

  def serialize
    hash = { "type" => action_type }
    hash["klass"] = klass_name if klass_name
    hash["from"] = from if from
    hash
  end
end

class TurnPhase::TargetedRemovalPhase < TurnPhase
  attr_reader :action_type, :klass_value, :pending_orders_value

  def self.from_hash(hash)
    new(
      action_type: hash.fetch("type"),
      klass_name: hash["klass"],
      pending_orders: Array(hash["pending_orders"])
    )
  end

  def initialize(action_type:, klass_name:, pending_orders:)
    @action_type = action_type
    @klass_value = klass_name
    @pending_orders_value = pending_orders
  end

  def type
    action_type
  end

  def klass_name
    klass_value
  end

  def pending_orders
    pending_orders_value
  end

  def consume_target(owner_order)
    remaining = pending_orders - [owner_order]
    if remaining.empty?
      TurnPhase::TransitionResult.new(
        next_phase: TurnPhase::MandatoryBuildPhase.new,
        action_completed: true,
        source_cleared: true
      )
    else
      TurnPhase::TransitionResult.new(
        next_phase: self.class.new(
          action_type: action_type,
          klass_name: klass_name,
          pending_orders: remaining
        ),
        action_completed: false,
        source_cleared: true
      )
    end
  end

  def serialize
    {
      "type" => action_type,
      "klass" => klass_name,
      "pending_orders" => pending_orders
    }
  end
end

class TurnPhase::MeepleActionPhase < TurnPhase
  attr_reader :action_type, :klass_value

  def self.from_hash(hash)
    new(
      action_type: hash.fetch("type"),
      klass_name: hash["klass"]
    )
  end

  def initialize(action_type:, klass_name:)
    @action_type = action_type
    @klass_value = klass_name
  end

  def type
    action_type
  end

  def klass_name
    klass_value
  end

  def serialize
    {
      "type" => action_type,
      "klass" => klass_name
    }
  end
end

class TurnPhase::CityHallPhase < TurnPhase
  attr_reader :action_type, :klass_value

  def self.from_hash(hash)
    new(
      action_type: hash.fetch("type"),
      klass_name: hash["klass"]
    )
  end

  def initialize(action_type:, klass_name:)
    @action_type = action_type
    @klass_value = klass_name
  end

  def type
    action_type
  end

  def klass_name
    klass_value
  end

  def serialize
    {
      "type" => action_type,
      "klass" => klass_name
    }
  end
end

class TurnPhase::LegacyPhase < TurnPhase
  attr_reader :data

  def initialize(data)
    @data = data.deep_stringify_keys
  end

  def builds
    Array(data["builds"])
  end

  def pending_orders
    Array(data["pending_orders"])
  end

  def outpost_active?
    data["outpost_active"] == true
  end

  def remaining
    data["remaining"]
  end

  def walls_placed
    data["walls_placed"]
  end

  def fort_terrain
    data["fort_terrain"]
  end

  def budget
    data["budget"]
  end

  def vacated
    Array(data["vacated"])
  end

  def moves
    data["moves"]
  end

  def serialize
    data.deep_dup
  end
end
