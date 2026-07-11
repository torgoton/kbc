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
    elsif tile&.resettles?
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

  # The tile class name for this phase's action, applying the type-derived
  # fallback for phases that carry no explicit "klass" (e.g. a quarry action
  # serializes only its type). Single source of truth for both #click and
  # TurnEngine#current_action_tile_klass.
  def tile_klass_name
    klass_name || "#{type.capitalize}Tile"
  end

  def chosen_terrain
    serialize["chosen_terrain"]
  end

  def from
    serialize["from"]
  end

  # Null-object defaults so the engine can ask any phase for these without a
  # respond_to? guard. Phases that own a concept override the accessor; phases
  # that don't return the neutral value the engine would otherwise default to.
  def budget = nil
  def moves = nil
  def remaining = nil
  def walls_placed = nil
  def fort_terrain = nil
  def pending_orders = []
  def outpost_active? = false

  # Phase-kind / capability questions the engine asks instead of probing the
  # concrete class. Phases that qualify override these.
  def meeple_movement? = false
  def mandatory_build? = false
  def city_hall? = false
  def tile_action_endable? = false
  # Clicking one of your own pieces starts a transition(SourceSelected) rather
  # than the LegacyPhase fallback. True for the move/resettlement phases.
  def accepts_source_selection? = false

  # Return a copy of this phase with the outpost power active. Non-build phases
  # fall back to a fresh mandatory build (the engine only activates the outpost
  # during a build action).
  def with_outpost_active
    TurnPhase::MandatoryBuildPhase.new(chosen_terrain: chosen_terrain, builds: [], outpost_active: true)
  end

  # Return a copy of this phase with its terrain locked in.
  def with_chosen_terrain(terrain)
    TurnPhase::MandatoryBuildPhase.new(chosen_terrain: terrain, builds: [], outpost_active: outpost_active?)
  end

  # Remove one targeted owner and advance. Lives on the base so the engine can
  # ask any current phase uniformly: a phase with remaining orders yields the
  # next TargetedRemovalPhase, otherwise the action completes back to mandatory.
  def consume_target(owner_order)
    remaining = pending_orders - [ owner_order ]
    if remaining.empty?
      TurnPhase::TransitionResult.new(
        next_phase: TurnPhase::MandatoryBuildPhase.new,
        action_completed: true,
        source_cleared: true
      )
    else
      TurnPhase::TransitionResult.new(
        next_phase: TurnPhase::TargetedRemovalPhase.new(
          action_type: type,
          klass_name: klass_name,
          pending_orders: remaining
        ),
        action_completed: false,
        source_cleared: true
      )
    end
  end

  # Interpret a board-cell click for this phase and drive the engine (State
  # pattern: phase = State, engine = Context). Base class reproduces the legacy
  # tile-predicate dispatch; concrete phases override with their own meaning.
  def click(coordinate, engine)
    row = coordinate.row
    col = coordinate.col
    # klass_name alone isn't enough: several phase subclasses only carry a
    # "klass" key when one was explicitly recorded (e.g. via select_action).
    tile = Tiles::Tile.for_klass(tile_klass_name)&.new(0)
    if tile&.moves_settlement?
      from ? engine.move_settlement(row, col) : engine.select_settlement(row, col)
    elsif tile&.sword_tile?
      engine.remove_settlement(row, col)
    elsif tile&.places_wall?
      engine.place_wall(row, col)
    elsif tile&.places_meeple?
      engine.execute_meeple_action(row, col)
    elsif tile&.places_city_hall?
      engine.place_city_hall(row, col)
    elsif tile&.builds_settlement?
      engine.activate_tile_build(row, col)
    else
      engine.build_settlement(row, col)
    end
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

  def mandatory_build? = true

  def with_outpost_active
    self.class.new(chosen_terrain: chosen_terrain, builds: builds, outpost_active: true)
  end

  def with_chosen_terrain(terrain)
    self.class.new(chosen_terrain: terrain, builds: builds, outpost_active: outpost_active?)
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
  attr_reader :action_type, :klass_value, :chosen_terrain_value, :remaining, :walls_placed, :outpost_active_value

  def self.from_hash(hash)
    new(
      action_type: hash.fetch("type"),
      klass_name: hash["klass"],
      chosen_terrain: hash["chosen_terrain"],
      remaining: hash["remaining"],
      walls_placed: hash["walls_placed"],
      outpost_active: hash["outpost_active"] == true
    )
  end

  def initialize(action_type:, klass_name:, chosen_terrain: nil, remaining: nil, walls_placed: nil, outpost_active: false)
    @action_type = action_type
    @klass_value = klass_name
    @chosen_terrain_value = chosen_terrain
    @remaining = remaining
    @walls_placed = walls_placed
    @outpost_active_value = outpost_active
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

  def outpost_active?
    outpost_active_value == true
  end

  def tile_action_endable? = walls_placed.to_i >= 1

  def with_outpost_active
    self.class.new(
      action_type: action_type,
      klass_name: klass_name,
      chosen_terrain: chosen_terrain,
      remaining: remaining,
      walls_placed: walls_placed,
      outpost_active: true
    )
  end

  def with_chosen_terrain(terrain)
    self.class.new(
      action_type: action_type,
      klass_name: klass_name,
      chosen_terrain: terrain,
      remaining: remaining,
      walls_placed: walls_placed
    )
  end

  def decrement_remaining
    self.class.new(
      action_type: action_type,
      klass_name: klass_name,
      chosen_terrain: chosen_terrain,
      remaining: remaining && remaining - 1,
      walls_placed: walls_placed,
      outpost_active: outpost_active?
    )
  end

  def increment_walls_placed
    self.class.new(
      action_type: action_type,
      klass_name: klass_name,
      chosen_terrain: chosen_terrain,
      remaining: remaining,
      walls_placed: walls_placed.to_i + 1,
      outpost_active: outpost_active?
    )
  end

  def serialize
    hash = { "type" => action_type }
    hash["klass"] = klass_name if klass_name
    hash["chosen_terrain"] = chosen_terrain if chosen_terrain
    hash["remaining"] = remaining if remaining
    hash["walls_placed"] = walls_placed if walls_placed
    hash["outpost_active"] = true if outpost_active?
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

  def accepts_source_selection? = true

  def click(coordinate, engine)
    if from
      engine.move_settlement(coordinate.row, coordinate.col)
    else
      engine.select_settlement(coordinate.row, coordinate.col)
    end
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
  attr_reader :budget_value, :moves_value, :from_value

  def self.from_hash(hash)
    new(
      budget: hash.fetch("budget"),
      moves: hash.fetch("moves"),
      from: hash["from"]
    )
  end

  def initialize(budget:, moves:, from: nil)
    @budget_value = budget
    @moves_value = moves
    @from_value = from
  end

  def type
    "resettlement"
  end

  def tile_action_endable? = moves.to_i >= 1
  def accepts_source_selection? = true

  def klass_name
    "ResettlementTile"
  end

  def click(coordinate, engine)
    if from
      engine.move_settlement(coordinate.row, coordinate.col)
    else
      engine.select_settlement(coordinate.row, coordinate.col)
    end
  end

  def budget
    budget_value
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
      "moves" => moves
    }
    hash["from"] = from if from
    hash
  end
end

class TurnPhase::MeepleMovementPhase < TurnPhase
  attr_reader :action_type, :klass_value, :from_value, :budget_value, :moves_value

  def self.from_hash(hash)
    new(
      action_type: hash.fetch("type"),
      klass_name: hash["klass"],
      from: hash["from"],
      budget: hash["budget"] || 3,
      moves: hash["moves"] || 0
    )
  end

  def initialize(action_type:, klass_name:, from: nil, budget: 3, moves: 0)
    @action_type = action_type
    @klass_value = klass_name
    @from_value = from
    @budget_value = budget
    @moves_value = moves
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

  def budget
    budget_value
  end

  def moves
    moves_value
  end

  def meeple_movement? = true
  def tile_action_endable? = moves.to_i >= 1
  def accepts_source_selection? = true

  def click(coordinate, engine)
    engine.execute_meeple_action(coordinate.row, coordinate.col)
  end

  def transition(event, facts)
    case event
    when TurnPhase::Events::SourceSelected
      TurnPhase::TransitionResult.new(
        next_phase: self.class.new(
          action_type: action_type,
          klass_name: klass_name,
          from: event.coordinate_key,
          budget: budget,
          moves: moves
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
    hash["budget"] = budget
    hash["moves"] = moves
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

  # consume_target is inherited from TurnPhase — its self.class is this class.

  def click(coordinate, engine)
    engine.remove_settlement(coordinate.row, coordinate.col)
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

  def click(coordinate, engine)
    engine.execute_meeple_action(coordinate.row, coordinate.col)
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

  def city_hall? = true

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

  def moves
    data["moves"]
  end

  def serialize
    data.deep_dup
  end
end
