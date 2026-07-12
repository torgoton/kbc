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
      raise ArgumentError, "no TurnPhase for #{hash.inspect}"
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

  # The tile object backing this phase's action (built from tile_klass_name),
  # used by legal_targets to delegate to the tile's own valid_destinations /
  # selectable_settlements. nil for phases with no tile (e.g. mandatory).
  def tile
    Tiles::Tile.for_klass(tile_klass_name)&.new(0)
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

  # The set of board cells (as [row, col]) that are legal action targets in
  # this phase — the cells the UI highlights and every action guard checks
  # (via TurnEngine#legal_targets). Each concrete phase owns its own rule
  # (State pattern); the base has none. `board_contents` is terrain-aware.
  def legal_targets(board_contents:, player:, game: nil)
    []
  end

  # The terrain this phase's build is locked to: the chosen terrain if the hand
  # was already committed, otherwise the sole hand card (a two-card hand stays
  # unlocked → nil). Shared by the build and settlement-move phases.
  def effective_terrain(player)
    chosen_terrain || (player.hand.size == 1 ? player.hand.first : nil)
  end

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
  # pattern: phase = State, engine = Context). Every concrete phase overrides
  # this with its own meaning; the base class never accepts a click directly.
  def click(_coordinate, _engine)
    raise InvalidTransition, "#{self.class.name} does not accept a board click"
  end

  # Popup gestures for clicking your own meeple. Only the meeple phases act on
  # them (MeepleOrchestration overrides these); any other phase degrades to
  # "Not available", as the engine's former remove_meeple_action /
  # select_meeple_for_move did via their held-tile guard — never a 500.
  def remove_meeple(_coordinate, _engine) = "Not available"
  def select_meeple(_coordinate, _engine) = "Not available"

  def transition(_event, _facts)
    raise InvalidTransition, "#{self.class.name} does not accept that event"
  end
end

# Shared legal-targets rule for the settlement movers (paddock/barn via
# SettlementMovePhase, resettlement via ResettlementPhase): before a source is
# picked, the selectable settlements; after, that settlement's valid
# destinations. Both thread the played terrain (a two-card hand widens the set)
# and the step budget (only ResettlementTile consumes it; other movers ignore
# it). The including phase supplies tile/from/budget/effective_terrain.
module TurnPhase::SettlementMoveTargets
  def legal_targets(board_contents:, player:, game: nil)
    terrains =
      if tile.uses_played_terrain? && effective_terrain(player).nil?
        player.hand
      else
        [ effective_terrain(player) || player.hand.first ]
      end
    step_budget = budget.to_i

    if from
      src = Coordinate.from_key(from)
      terrains.flat_map do |terrain|
        tile.valid_destinations(
          from_row: src.row, from_col: src.col, board_contents: board_contents,
          player_order: player.order, hand: terrain, budget: step_budget
        )
      end.uniq
    else
      terrains.flat_map do |terrain|
        tile.selectable_settlements(
          player_order: player.order, board_contents: board_contents,
          hand: terrain, budget: step_budget
        )
      end.uniq
    end
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

  def legal_targets(board_contents:, player:, game: nil)
    return [] unless player.settlements_remaining? && game.mandatory_count > 0
    terrains = effective_terrain(player) ? [ effective_terrain(player) ] : player.hand
    if outpost_active?
      board_contents.available_cells_of(terrains)
    else
      terrains.flat_map { |terrain| board_contents.buildable_cells_for(player.order, terrain) }.uniq
    end
  end

  # Build a mandatory settlement. This phase owns the action; the engine supplies
  # the shared primitives. Outpost waives adjacency and re-derives the card from
  # the clicked hex; otherwise a still-unlocked two-card hand is disambiguated by
  # which card can legally build on the clicked cell (available_list).
  def click(coordinate, engine)
    row, col = coordinate.row, coordinate.col
    engine.capture_undo_snapshot
    game = engine.game
    game.instantiate
    game_player = game.current_player
    return "No settlements left" unless game_player.settlements_remaining?
    chosen_terrain_before = chosen_terrain
    card_terrain = effective_terrain(game_player)

    if outpost_active?
      return "Not available" unless engine.legal_targets.include?([ row, col ])
      card_terrain ||= game_player.hand.find { |t| game.board_contents.terrain_at(row, col) == t }
      engine.lock_terrain!(card_terrain, chosen_terrain_before) unless chosen_terrain_before
      engine.build_on_terrain(card_terrain, row, col, game_player)
      game.mandatory_count -= 1
      phase_result = transition(
        TurnPhase::Events::BuildChosen.new(coordinate: [ row, col ]),
        TurnPhase::Facts::BuildChoice.new(locked_terrain: card_terrain)
      )
      game.turn_phase = TurnPhase::MandatoryBuildPhase.new(
        chosen_terrain: phase_result.next_phase.chosen_terrain,
        builds: phase_result.next_phase.builds
      )
    else
      return "Not available" unless engine.legal_targets.include?([ row, col ])
      if card_terrain.nil?
        card_terrain = game_player.hand.find { |t|
          list = engine.available_list(game_player.order, t)
          list.any? ? list[row][col] : true
        }
        engine.lock_terrain!(card_terrain, chosen_terrain_before)
      end
      engine.build_on_terrain(card_terrain, row, col, game_player)
      game.mandatory_count -= 1
      phase_result = transition(
        TurnPhase::Events::BuildChosen.new(coordinate: [ row, col ]),
        TurnPhase::Facts::BuildChoice.new(locked_terrain: card_terrain)
      )
      game.turn_phase = phase_result.next_phase
    end

    builds = game.turn_phase.builds || []
    engine.check_families_goal(game_player) if builds.size == 3
    game_player.save
    game.save
  end

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

# Shared build orchestration for the tile-build phases: TileBuildPhase's
# non-wall branch (village/farm/oracle/donationdesert/...) and FortPhase. The
# including phase supplies its own type/klass_name/chosen_terrain/remaining; the
# engine supplies the shared mutation primitives. self's chosen_terrain and
# remaining are read directly — self is immutable, so they carry the pre-lock
# values, matching the engine's former stale `current_phase` reads exactly.
module TurnPhase::TileBuildOrchestration
  def build_tile(coordinate, engine)
    row, col = coordinate.row, coordinate.col
    engine.capture_undo_snapshot
    game = engine.game
    game.instantiate
    game_player = game.current_player
    return "No settlements left" unless game_player.settlements_remaining?
    tile_klass = tile_klass_name
    tile = game_player.find_unused_tile(tile_klass)
    return "Not available" unless tile
    tile_obj = Tiles::Tile.from_hash(tile)
    return "Not available" unless engine.legal_targets.include?([ row, col ])
    if tile_obj.uses_played_terrain? && chosen_terrain.nil? && game_player.hand.size > 1
      engine.lock_terrain!(game.board_contents.terrain_at(row, col), chosen_terrain)
    end
    engine.build_on_terrain(game.board_contents.terrain_at(row, col), row, col, game_player, tile_klass: tile_klass)
    if tile_obj.repeats_build?
      remaining_after = remaining.to_i - 1
      if remaining_after > 0
        game.turn_phase = TurnPhase::TileBuildPhase.new(
          action_type: type,
          klass_name: klass_name,
          chosen_terrain: chosen_terrain,
          remaining: remaining_after
        )
      else
        game_player.mark_tile_used!(tile_klass)
        engine.reset_to_mandatory
      end
    else
      game_player.mark_tile_used!(tile_klass)
      engine.reset_to_mandatory
    end
    game_player.save
    game.save
  end
end

class TurnPhase::TileBuildPhase < TurnPhase
  include TurnPhase::TileBuildOrchestration
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

  def legal_targets(board_contents:, player:, game: nil)
    return [] if tile.places_wall? && game.stone_walls <= 0
    if tile.builds_settlement? && outpost_active?
      board_contents.available_cells_of(outpost_terrains(player))
    else
      played_terrain_targets(board_contents, player)
    end
  end

  # This phase spans both wall tiles (quarry) and build tiles (village, farm,
  # ...), so it asks its OWN reconstructed tile which one it is (`tile` applies
  # the type-derived klass fallback — a quarry action serializes no "klass").
  # Walls have their own orchestration; everything else shares build_tile.
  def click(coordinate, engine)
    if tile&.places_wall?
      place_wall_step(coordinate, engine)
    else
      build_tile(coordinate, engine)
    end
  end

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

  private

  # Place one stone wall (QuarryTile). Locking the played terrain replaces
  # game.turn_phase with a locked copy, so after a lock we continue from that
  # new phase (current_phase) — its increment_walls_placed keeps the lock.
  def place_wall_step(coordinate, engine)
    row, col = coordinate.row, coordinate.col
    engine.capture_undo_snapshot
    game = engine.game
    game.instantiate
    game_player = game.current_player

    tile_obj = Tiles::Location::QuarryTile.new(0)
    return "No stone walls left" if game.stone_walls <= 0
    return "Not available" unless engine.legal_targets.include?([ row, col ])

    current_phase = self
    if chosen_terrain.nil? && game_player.hand.size > 1
      engine.lock_terrain!(game.board_contents.terrain_at(row, col), chosen_terrain)
      current_phase = game.turn_phase
    end
    wall_terrain = current_phase.effective_terrain(game_player)

    walls_placed_after = current_phase.walls_placed.to_i + 1

    engine.record_move(
      action: "place_wall",
      deliberate: true,
      reversible: true,
      game_player: game_player,
      to: "[#{row}, #{col}]",
      message: "#{game_player.player.handle} placed a stone wall at [#{row}, #{col}]"
    )

    game.board_contents_will_change!
    game.board_contents.place_wall(row, col)
    game.stone_walls -= 1

    remaining = tile_obj.valid_destinations(
      board_contents: game.board_contents,
      player_order: game_player.order, hand: wall_terrain || game_player.hand.first
    )
    if walls_placed_after >= 2 || remaining.empty?
      game_player.mark_tile_used!("QuarryTile")
      engine.reset_to_mandatory
    else
      game.turn_phase = current_phase.increment_walls_placed
    end

    game_player.save
    game.save
  end

  # Destinations on the tile's terrain: a fixed-terrain tile (Farm/Oasis/...)
  # ignores the hand; a played-terrain tile (Oracle/Quarry) uses the locked
  # terrain, or spans both cards of an as-yet-unlocked two-card hand.
  def played_terrain_targets(board_contents, player)
    if tile.uses_played_terrain? && effective_terrain(player).nil?
      player.hand.flat_map do |terrain|
        tile.valid_destinations(board_contents: board_contents, player_order: player.order, hand: terrain)
      end.uniq
    else
      tile.valid_destinations(
        board_contents: board_contents, player_order: player.order,
        hand: effective_terrain(player) || player.hand.first
      )
    end
  end

  # The terrain(s) an Outpost build may target (adjacency waived): a played-
  # terrain tile with an unlocked two-card hand spans both, otherwise the tile's
  # fixed build terrain (or the locked/sole hand card).
  def outpost_terrains(player)
    if tile.uses_played_terrain? && effective_terrain(player).nil?
      player.hand
    else
      [ tile.build_terrain || effective_terrain(player) || player.hand.first ].compact
    end
  end
end

class TurnPhase::FortPhase < TurnPhase
  include TurnPhase::TileBuildOrchestration
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

  def legal_targets(board_contents:, player:, game: nil)
    tile.valid_destinations(
      board_contents: board_contents, player_order: player.order, hand: fort_terrain
    )
  end

  def click(coordinate, engine)
    build_tile(coordinate, engine)
  end

  def serialize
    {
      "type" => "fort",
      "klass" => "FortTile",
      "fort_terrain" => fort_terrain
    }
  end
end

# Shared click orchestration for the settlement movers (SettlementMovePhase,
# ResettlementPhase): the first click selects the source, the next resolves the
# move. select_source is identical for both; each phase supplies its own move_to
# (a single move vs a stepped/budgeted one). Companion to SettlementMoveTargets,
# which owns the legal-target rule.
module TurnPhase::SettlementMoveOrchestration
  def click(coordinate, engine)
    if from
      move_to(coordinate, engine)
    else
      select_source(coordinate, engine)
    end
  end

  def select_source(coordinate, engine)
    engine.capture_undo_snapshot
    game = engine.game
    key = "[#{coordinate.row}, #{coordinate.col}]"
    engine.record_move(
      action: "select_settlement",
      deliberate: true,
      reversible: true,
      from: key,
      message: "#{game.current_player.player.handle} selected a settlement at #{key}"
    )
    phase_result = transition(TurnPhase::Events::SourceSelected.new(coordinate_key: key), nil)
    game.turn_phase = phase_result.next_phase
    game.save
  end

  private

  # Lock the played terrain before a move resolves, for a played-terrain mover
  # (Barn) on a still-unlocked two-card hand. Mirrors the engine's former
  # preamble: locking replaces game.turn_phase, so move_to reads the resulting
  # terrain back from game.turn_phase (not self, which stays pre-lock).
  def lock_move_terrain(row, col, engine)
    game = engine.game
    if tile&.uses_played_terrain? && chosen_terrain.nil? && game.current_player.hand.size > 1
      engine.lock_terrain!(game.board_contents.terrain_at(row, col), chosen_terrain)
    end
  end
end

class TurnPhase::SettlementMovePhase < TurnPhase
  include TurnPhase::SettlementMoveTargets
  include TurnPhase::SettlementMoveOrchestration
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

  # A single settlement move (paddock/harbor/barn). Reads hand terrain back from
  # game.turn_phase so a locked two-card Barn move validates against the locked
  # terrain; from/transition come from self (pre-lock, so the source survives).
  def move_to(coordinate, engine)
    row, col = coordinate.row, coordinate.col
    engine.capture_undo_snapshot
    game = engine.game
    game.instantiate
    from_coord = Coordinate.from_key(from)
    tile_klass = tile_klass_name
    tile_obj = tile
    lock_move_terrain(row, col, engine)
    hand_arg = game.turn_phase.effective_terrain(game.current_player) || game.current_player.hand.first
    return "Not available" unless tile_obj.valid_destinations(
      from_row: from_coord.row, from_col: from_coord.col,
      board_contents: game.board_contents, player_order: game.current_player.order, hand: hand_arg
    ).include?([ row, col ])
    engine.record_move(
      action: "move_settlement",
      deliberate: true,
      reversible: true,
      from: from,
      to: Coordinate.new(row, col).to_key,
      payload: { "tile_klass" => tile_klass },
      message: "#{game.current_player.player.handle} moved a settlement to [#{row}, #{col}]"
    )
    game.board_contents_will_change!
    game.board_contents.move_settlement(*from_coord, row, col)
    phase_result = transition(
      TurnPhase::Events::DestinationChosen.new,
      TurnPhase::Facts::DestinationChoice.new(next_phase: TurnPhase::MandatoryBuildPhase.new)
    )
    game.turn_phase = phase_result.next_phase
    game.current_player.mark_tile_used!(tile_klass)
    engine.apply_tile_forfeit(game.current_player)
    engine.apply_tile_pickup(game.current_player, row, col)
    game.current_player.save
    game.save
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
  include TurnPhase::SettlementMoveTargets
  include TurnPhase::SettlementMoveOrchestration
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
  def klass_name
    "ResettlementTile"
  end

  # One step of a budgeted resettlement move. The budget/moves come from self;
  # the tile validates the single-step destination against the remaining budget.
  def move_to(coordinate, engine)
    row, col = coordinate.row, coordinate.col
    engine.capture_undo_snapshot
    game = engine.game
    game.instantiate
    from_coord = Coordinate.from_key(from)
    tile_klass = tile_klass_name
    tile_obj = tile
    lock_move_terrain(row, col, engine)
    return "Not available" unless budget.to_i > 0 &&
      tile_obj.valid_destinations(
        from_row: from_coord.row, from_col: from_coord.col,
        board_contents: game.board_contents,
        player_order: game.current_player.order, budget: budget.to_i
      ).include?([ row, col ])

    new_budget = budget.to_i - 1
    new_moves = moves.to_i + 1
    next_phase =
      if new_budget <= 0
        TurnPhase::MandatoryBuildPhase.new
      else
        TurnPhase::ResettlementPhase.new(budget: new_budget, moves: new_moves)
      end
    engine.log_piece_movement_steps(
      action: "move_settlement",
      game_player: game.current_player,
      from_row: from_coord.row, from_col: from_coord.col,
      path: [ [ row, col ] ],
      payload: { "tile_klass" => tile_klass },
      message_piece: "settlement"
    )
    if new_budget <= 0
      game.current_player.mark_tile_used!(tile_klass)
      game.turn_phase = next_phase
    else
      phase_result = transition(
        TurnPhase::Events::DestinationChosen.new,
        TurnPhase::Facts::DestinationChoice.new(next_phase: next_phase)
      )
      game.turn_phase = phase_result.next_phase
    end
    game.current_player.save
    game.save
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

# Shared click orchestration for the meeple placers/movers (MeepleActionPhase
# for warriors, MeepleMovementPhase for ships/wagons): generic on
# tile.meeple_kind, mirroring the engine's former dispatch. click places a
# piece or advances a movement step; select_meeple/remove_meeple are the
# "popup" gestures on the player's own piece (opening the move/remove choice),
# routed here from the controller rather than through a board click.
module TurnPhase::MeepleOrchestration
  def click(coordinate, engine)
    row, col = coordinate.row, coordinate.col
    engine.capture_undo_snapshot
    game = engine.game
    game.instantiate
    game_player = game.current_player
    tile_klass = tile_klass_name
    tile = game_player.find_unused_tile(tile_klass)
    return "Not available" unless tile

    tile_obj = Tiles::Tile.from_hash(tile)

    movement_step = false
    if from
      # complete a ship or wagon move to destination
      return "Not available" unless engine.legal_targets.include?([ row, col ])
      movement_result = case tile_obj.meeple_kind
      when "ship"  then move_ship(row, col, game_player, tile_klass:, engine:)
      when "wagon" then move_wagon(row, col, game_player, tile_klass:, engine:)
      end
      return movement_result if movement_result.is_a?(String)
      movement_step = true
    elsif game.board_contents.wagon_at?(row, col) &&
          game.board_contents.player_at(row, col) == game_player.order
      return "Not available"  # handled by popup: remove_meeple or select_meeple
    elsif game.board_contents.ship_at?(row, col) &&
          game.board_contents.player_at(row, col) == game_player.order
      return "Not available"  # handled by popup: remove_meeple or select_meeple
    elsif game.board_contents.warrior_at?(row, col) &&
          game.board_contents.player_at(row, col) == game_player.order
      return "Not available"  # handled by popup: remove_meeple
    else
      return "Not available" unless engine.legal_targets.include?([ row, col ])
      case tile_obj.meeple_kind
      when "ship"    then place_ship(row, col, game_player, tile_klass:, engine:)
      when "wagon"   then place_wagon(row, col, game_player, tile_klass:, engine:)
      when "warrior" then place_warrior(row, col, game_player, tile_klass:, engine:)
      end
    end

    unless movement_step && game.turn_phase.meeple_movement?
      game_player.mark_tile_used!(tile_klass)
      engine.reset_to_mandatory
    end
    game_player.save
    game.save
  end

  # Remove the player's own placed meeple (warrior/ship/wagon), returning it to
  # supply.
  def remove_meeple(coordinate, engine)
    row, col = coordinate.row, coordinate.col
    engine.capture_undo_snapshot
    game = engine.game
    game.instantiate
    game_player = game.current_player
    tile_klass = tile_klass_name
    tile = game_player.find_unused_tile(tile_klass)
    return "Not available" unless tile

    if game.board_contents.warrior_at?(row, col) &&
       game.board_contents.player_at(row, col) == game_player.order
      remove_warrior(row, col, game_player, tile_klass:, engine:)
    elsif game.board_contents.ship_at?(row, col) &&
          game.board_contents.player_at(row, col) == game_player.order
      remove_ship(row, col, game_player, tile_klass:, engine:)
    elsif game.board_contents.wagon_at?(row, col) &&
          game.board_contents.player_at(row, col) == game_player.order
      remove_wagon(row, col, game_player, tile_klass:, engine:)
    else
      return "Not available"
    end

    game_player.mark_tile_used!(tile_klass)
    engine.reset_to_mandatory
    game_player.save
    game.save
  end

  # Select the player's own ship/wagon as the source of a move (a warrior has
  # no meeple_kind match here, so this is always "Not available" for
  # MeepleActionPhase).
  def select_meeple(coordinate, engine)
    row, col = coordinate.row, coordinate.col
    engine.capture_undo_snapshot
    game = engine.game
    game.instantiate
    game_player = game.current_player
    tile_klass = tile_klass_name
    tile = game_player.find_unused_tile(tile_klass)
    return "Not available" unless tile

    tile_obj = Tiles::Tile.from_hash(tile)
    moveable = case tile_obj.meeple_kind
    when "ship"  then game.board_contents.ship_at?(row, col)
    when "wagon" then game.board_contents.wagon_at?(row, col)
    else false
    end
    return "Not available" unless moveable
    return "Not available" unless game.board_contents.player_at(row, col) == game_player.order

    destinations = tile_obj.valid_destinations(
      from_row: row, from_col: col,
      board_contents: game.board_contents,
      player_order: game_player.order
    )
    return "Not available" unless destinations.any?

    action_word = tile_obj.meeple_kind
    engine.record_move(
      action: "select_#{action_word}",
      deliberate: true,
      reversible: true,
      game_player: game_player,
      from: "[#{row}, #{col}]",
      message: "#{game_player.player.handle} selected their #{action_word} at [#{row}, #{col}]"
    )
    phase_result = transition(
      TurnPhase::Events::SourceSelected.new(coordinate_key: "[#{row}, #{col}]"),
      nil
    )
    game.turn_phase = phase_result.next_phase
    game.save
  end

  private

  def place_warrior(row, col, game_player, tile_klass:, engine:)
    engine.record_move(
      action: "place_warrior",
      deliberate: true,
      reversible: true,
      game_player: game_player,
      to: "[#{row}, #{col}]",
      payload: { "klass" => tile_klass },
      message: "#{game_player.player.handle} placed a warrior at [#{row}, #{col}]"
    )
    game = engine.game
    game.board_contents_will_change!
    game.board_contents.place_warrior(row, col, game_player.order)
    game_player.decrement_warrior_supply!
    engine.apply_tile_pickup(game_player, row, col)
  end

  def remove_warrior(row, col, game_player, tile_klass:, engine:)
    engine.record_move(
      action: "remove_warrior",
      deliberate: true,
      reversible: true,
      game_player: game_player,
      from: "[#{row}, #{col}]",
      payload: { "klass" => tile_klass },
      message: "#{game_player.player.handle} removed a warrior from [#{row}, #{col}]"
    )
    game = engine.game
    game.board_contents_will_change!
    game.board_contents.remove(row, col)
    game_player.increment_warrior_supply!
    engine.apply_tile_forfeit(game_player)
  end

  def place_ship(row, col, game_player, tile_klass:, engine:)
    engine.record_move(
      action: "place_ship",
      deliberate: true,
      reversible: true,
      game_player: game_player,
      to: "[#{row}, #{col}]",
      payload: { "klass" => tile_klass },
      message: "#{game_player.player.handle} placed their ship at [#{row}, #{col}]"
    )
    game = engine.game
    game.board_contents_will_change!
    game.board_contents.place_ship(row, col, game_player.order)
    game_player.decrement_ship_supply!
    engine.apply_tile_pickup(game_player, row, col)
  end

  def remove_ship(row, col, game_player, tile_klass:, engine:)
    engine.record_move(
      action: "remove_ship",
      deliberate: true,
      reversible: true,
      game_player: game_player,
      from: "[#{row}, #{col}]",
      payload: { "klass" => tile_klass },
      message: "#{game_player.player.handle} removed their ship from [#{row}, #{col}]"
    )
    game = engine.game
    game.board_contents_will_change!
    game.board_contents.remove(row, col)
    game_player.increment_ship_supply!
    engine.apply_tile_forfeit(game_player)
  end

  def move_ship(row, col, game_player, tile_klass:, engine:)
    from_coord = Coordinate.from_key(from)
    meeple_phase_after_step(row, col, tile_klass, engine:)

    engine.log_piece_movement_steps(
      action: "move_ship",
      game_player: game_player,
      from_row: from_coord.row, from_col: from_coord.col,
      path: [ [ row, col ] ],
      payload: { "klass" => tile_klass },
      message_piece: "ship"
    )
  end

  def place_wagon(row, col, game_player, tile_klass:, engine:)
    engine.record_move(
      action: "place_wagon",
      deliberate: true,
      reversible: true,
      game_player: game_player,
      to: "[#{row}, #{col}]",
      payload: { "klass" => tile_klass },
      message: "#{game_player.player.handle} placed their wagon at [#{row}, #{col}]"
    )
    game = engine.game
    game.board_contents_will_change!
    game.board_contents.place_wagon(row, col, game_player.order)
    game_player.decrement_wagon_supply!
    engine.apply_tile_pickup(game_player, row, col)
  end

  def remove_wagon(row, col, game_player, tile_klass:, engine:)
    engine.record_move(
      action: "remove_wagon",
      deliberate: true,
      reversible: true,
      game_player: game_player,
      from: "[#{row}, #{col}]",
      payload: { "klass" => tile_klass },
      message: "#{game_player.player.handle} removed their wagon from [#{row}, #{col}]"
    )
    game = engine.game
    game.board_contents_will_change!
    game.board_contents.remove(row, col)
    game_player.increment_wagon_supply!
    engine.apply_tile_forfeit(game_player)
  end

  def move_wagon(row, col, game_player, tile_klass:, engine:)
    from_coord = Coordinate.from_key(from)
    meeple_phase_after_step(row, col, tile_klass, engine:)

    engine.log_piece_movement_steps(
      action: "move_wagon",
      game_player: game_player,
      from_row: from_coord.row, from_col: from_coord.col,
      path: [ [ row, col ] ],
      payload: { "klass" => tile_klass },
      message_piece: "wagon"
    )
  end

  # A ship/wagon move step never swaps the phase before this runs, so
  # budget/type/klass_name read from self (the phase currently dispatching the
  # click), not from a fresh game.turn_phase lookup.
  def meeple_phase_after_step(row, col, tile_klass, engine:)
    game = engine.game
    new_budget = budget.to_i - 1
    new_moves = moves.to_i + 1
    if new_budget <= 0
      game.current_player.mark_tile_used!(tile_klass)
      game.turn_phase = TurnPhase::MandatoryBuildPhase.new
    else
      game.turn_phase = TurnPhase::MeepleMovementPhase.new(
        action_type: type,
        klass_name: klass_name,
        from: Coordinate.new(row, col).to_key,
        budget: new_budget,
        moves: new_moves
      )
    end
  end
end

class TurnPhase::MeepleMovementPhase < TurnPhase
  include TurnPhase::MeepleOrchestration
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
  def legal_targets(board_contents:, player:, game: nil)
    if from
      return [] if budget.to_i <= 0
      src = Coordinate.from_key(from)
      destinations = tile.valid_destinations(
        from_row: src.row, from_col: src.col,
        board_contents: board_contents, player_order: player.order
      )
      board_contents.neighbors(src.row, src.col).select { |cell| destinations.include?(cell) }
    else
      tile.valid_destinations(
        board_contents: board_contents, player_order: player.order, supply: player.supply_hash
      )
    end
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

  def legal_targets(board_contents:, player:, game: nil)
    pending_orders.flat_map do |order|
      board_contents.settlements_for(order).reject { |r, c| board_contents.city_hall_at?(r, c) }
    end
  end

  # Remove a targeted settlement (State pattern: this phase owns the action's
  # orchestration; the engine supplies the shared primitives it calls —
  # capture_undo_snapshot / legal_targets / record_move / apply_tile_forfeit).
  def click(coordinate, engine)
    row, col = coordinate.row, coordinate.col
    engine.capture_undo_snapshot
    game = engine.game
    game.instantiate
    game_player = game.current_player

    return "Not a valid target" unless engine.legal_targets.include?([ row, col ])
    owner_order = game.board_contents.player_at(row, col)
    owner = game.game_players.find { |gp| gp.order == owner_order }

    phase_result = consume_target(owner_order)
    tile_used = phase_result.action_completed
    meeple = game.board_contents.meeple_at(row, col)

    engine.record_move(
      action: "remove_settlement",
      deliberate: true,
      reversible: true,
      game_player: game_player,
      from: "[#{row}, #{col}]",
      to: "player_#{owner_order}_supply",
      payload: { "owner_order" => owner_order, "tile_used" => tile_used, "meeple" => meeple },
      message: "#{game_player.player.handle} removed #{owner.player.handle}'s #{meeple || 'settlement'}"
    )

    game.board_contents_will_change!
    game.board_contents.remove(row, col)
    owner.return_piece_to_supply!(meeple)
    engine.apply_tile_forfeit(owner)

    if tile_used
      game_player.mark_tile_used!(tile_klass_name)
      game.turn_phase = TurnPhase::MandatoryBuildPhase.new
    else
      game.turn_phase = phase_result.next_phase
    end

    owner.save
    game_player.save
    game.save
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
  include TurnPhase::MeepleOrchestration
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

  def legal_targets(board_contents:, player:, game: nil)
    tile.valid_destinations(
      board_contents: board_contents, player_order: player.order, supply: player.supply_hash
    )
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

  def legal_targets(board_contents:, player:, game: nil)
    tile.valid_destinations(
      board_contents: board_contents, player_order: player.order, supply: player.supply_hash
    )
  end

  # Place the City Hall's 7-hex cluster (State pattern: this phase owns the
  # action's orchestration; the engine supplies the shared primitives it calls
  # — capture_undo_snapshot / legal_targets / record_move / reset_to_mandatory).
  def click(coordinate, engine)
    row, col = coordinate.row, coordinate.col
    engine.capture_undo_snapshot
    game = engine.game
    game.instantiate
    game_player = game.current_player
    return "No City Hall tile" unless game_player.find_unused_tile("CityHallTile")
    return "Not available" unless engine.legal_targets.include?([ row, col ])

    tile_obj = Tiles::Location::CityHallTile.new(0)
    cluster = tile_obj.cluster_hexes(row, col, game.board_contents)

    engine.record_move(
      action: "place_city_hall",
      deliberate: true,
      reversible: true,
      game_player: game_player,
      to: "[#{row}, #{col}]",
      message: "#{game_player.player.handle} placed their City Hall at [#{row}, #{col}]"
    )

    game.board_contents_will_change!
    cluster.each { |r, c| game.board_contents.place_city_hall_hex(r, c, game_player.order) }
    game_player.decrement_city_hall_supply!
    game_player.mark_tile_permanently_used!("CityHallTile")
    engine.reset_to_mandatory
    game_player.save
    game.save
  end

  def serialize
    {
      "type" => action_type,
      "klass" => klass_name
    }
  end
end
