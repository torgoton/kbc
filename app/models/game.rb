# == Schema Information
#
# Table name: games
#
#  id                :bigint           not null, primary key
#  board_contents    :json
#  boards            :json
#  completed_at      :datetime
#  current_action    :json
#  deck              :json
#  discard           :json
#  end_trigger_count :integer          default(0), not null
#  goals             :json
#  mandatory_count   :integer
#  move_count        :integer
#  scores            :json
#  speed             :string
#  state             :string
#  stone_walls       :integer          default(25), not null
#  tasks             :json
#  turn_number       :integer          default(0), not null
#  turn_started_at   :datetime
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  current_player_id :integer
#
# Indexes
#
#  index_games_on_current_player_id  (current_player_id)
#
class Game < ApplicationRecord
  STATES = [ "waiting", "playing", "completed" ]
  DECK = "C" * 5 + "D" * 5 + "F" * 5 + "G" * 5 + "T" * 5
  MANDATORY_COUNT = 3
  SETTLEMENTS_PER_PLAYER = 40
  SPEEDS = {
    "blitz" => { bank_ms: 300_000, increment_ms: 20_000 },
    "normal" => { bank_ms: 600_000, increment_ms: 30_000 }
  }.freeze

  has_many :game_players, dependent: :destroy
  has_many :players, through: :game_players, dependent: :delete_all
  has_many :moves, dependent: :destroy
  has_many :chat_messages, dependent: :destroy
  belongs_to :current_player, class_name: "GamePlayer", optional: true

  serialize :board_contents, coder: BoardState

  validates :state, inclusion: { in: STATES }
  validates :speed, inclusion: { in: SPEEDS.keys }, allow_nil: true

  attr_accessor :board

  after_find do |_game|
    update(state: "waiting") unless state
  end

  def add_player(user)
    players << user
  end

  def reset_players
    game_players.each do |gp|
      gp.update(order: nil, hand: nil, supply: nil, tiles: nil, taken_from: nil)
    end
  end

  scope :playing, -> { where(state: "playing") }
  scope :waiting, -> { where(state: "waiting") }
  scope :completed, -> { where(state: "completed") }

  def playing?
    state.to_s == "playing"
  end

  def waiting?
    state.to_s == "waiting"
  end

  def completed?
    state.to_s == "completed"
  end

  CHAT_OPEN_AFTER_COMPLETION = 10.minutes

  def chat_open?
    !completed? || (completed_at.present? && Time.current < completed_at + CHAT_OPEN_AFTER_COMPLETION)
  end

  def start(safe = true, options = {})
    if game_players.count < 2
      Rails.logger.warn "Cannot start game with less than 2 players"
      return false
    end
    if safe
      # Ensure we have a valid state to start from
      if !waiting?
        Rails.logger.warn "Cannot start game in state #{state}"
        return false
      end
    else
      Rails.logger.debug "FORCING start of game #{id} in state #{state}"
      reset_players
      self.moves.destroy_all
    end
    self.state = "playing"
    self.move_count = (move_count || 0) + 1
    moves.build(order: move_count, action: "start_game", message: "Game started.", deliberate: false, reversible: false)
    self.mandatory_count = MANDATORY_COUNT
    select_boards(options)
    populate_boards(options)
    select_goals
    initialize_terrain_deck
    select_tasks
    populate_player_supplies
    deal_terrain_cards
    choose_start_player
    start_clocks
    self.current_action = { "type" => "mandatory" }
    save
  end

  def restart(options = {})
    if User.count < 2
      Rails.logger.fatal "Cannot restart game with less than 2 users in the system"
      return false
    end
    self.moves.destroy_all
    self.discard ? self.discard.clear : self.discard = DECK.chars
    self.scores ? self.scores.clear : self.scores = {}
    @board = nil
    start(false, options)
  end

  def ending?
    end_trigger_count > 0
  end

  def turn_state
    return "Waiting for players" if waiting?
    return "Game has ended" if completed?
    TurnEngine.new(self).turn_state
  end

  def turn_phase
    TurnPhase.deserialize(current_action)
  end

  def turn_phase=(phase)
    self.current_action = phase.serialize
  end

  def my_turn?(user)
    playing? && current_player&.player == user
  end

  def timed?
    speed.present?
  end

  # Live remaining bank for game_player, in ms. Only the current player's
  # clock ticks, and only after their first deliberate move of the game
  # (clock_started_at); everyone else just sees their stored value.
  def time_remaining_for(game_player)
    stored = game_player.time_remaining_ms.to_i
    return stored unless playing? && game_player == current_player && game_player.clock_started_at.present?
    window_start = [ turn_started_at, game_player.clock_started_at ].compact.max
    elapsed_ms = ((Time.current - window_start) * 1000).to_i
    stored - elapsed_ms
  end

  def flagged?(game_player)
    timed? && playing? && game_player == current_player && time_remaining_for(game_player) <= 0
  end

  # Whether game_player's clock is ticking right now: their turn AND they've
  # made their first real game move (clock_started_at is stamped only by
  # TurnEngine#record_move on the first deliberate move — opening or joining
  # a table never starts a clock). Drives the countdown display.
  def clock_running_for?(game_player)
    timed? && playing? && game_player == current_player && game_player.clock_started_at.present?
  end

  # View logic lives here, not in the controller/view: an opponent may claim
  # victory once the current player is flagged.
  def claimable_by?(user)
    return false unless timed? && current_player && flagged?(current_player)
    game_player = game_players.find { |gp| gp.player == user }
    game_player.present? && game_player != current_player && !game_player.resigned?
  end

  # Short badge for dashboard listings, e.g. "⚡ Blitz 3+15", so nobody joins
  # a timed table unknowingly.
  def speed_label
    return nil unless timed?
    bank_min = SPEEDS[speed][:bank_ms] / 60_000
    increment_sec = SPEEDS[speed][:increment_ms] / 1_000
    "⚡ #{speed.capitalize} #{bank_min}+#{increment_sec}"
  end

  def player_handles
    game_players.map { |gp| gp.player.handle }.join(", ")
  end

  def live_scores
    Scoring.new(self).compute
  end

  # Stable domain query: the hexes where game_player may legally build right
  # now. Delegates to the engine's availability rule; returns coordinate pairs.
  def legal_builds(game_player, terrain: nil)
    terrain ||= Array(game_player.hand).first
    instantiate
    list = TurnEngine.new(self).available_list(game_player.order, terrain)
    return [] unless list
    list.each_with_index.flat_map do |row_cells, row|
      row_cells.each_index.select { |col| row_cells[col] }.map { |col| [ row, col ] }
    end
  end

  # Stable domain query: the held tiles game_player could activate right now
  # (unused, recognized klass, and permitted in the current turn phase).
  def available_tile_actions(game_player)
    instantiate
    engine = TurnEngine.new(self)
    (game_player.tiles || []).select { |tile| engine.tile_activatable?(tile) }
  end

  # Stable domain query: game_player's current points for one goal or task.
  # Raises KeyError if the goal is not part of this game.
  def score_for(goal, game_player)
    Scoring.new(self).score_for(game_player).fetch(goal.to_s)[:score]
  end

  def complete!
    self.state = "completed"
    self.current_player = nil
    self.scores = Scoring.new(self).compute
    self.mandatory_count = 0
    self.completed_at = Time.current
    transaction do
      save!
      Rating.new(self).apply!
    end
    log_game_results
    chat_messages.create!(body: "Game ended.")
    broadcast_game_update
    broadcast_end_game
    broadcast_dashboard_update
  end

  def broadcast_end_game
    broadcast_append_to(
      "game_#{id}",
      target: "game-area",
      partial: "games/end_game_modal",
      locals: { game: self, scores: scores }
    )
  end

  def winners
    return [] unless state == "completed" && scores.present?
    eligible = game_players.reject(&:resigned?)
    return eligible if eligible.length < game_players.length
    max_total = eligible.map { |gp| scores[gp.order.to_s]["total"] }.max
    eligible.select { |gp| scores[gp.order.to_s]["total"] == max_total }
  end

  def instantiate
    # Create objects from the serialized game state
    @board ||= Boards::Board.new(self)
    board_contents.terrain_source = @board
    @board
  end

  def broadcast_dashboard_update
    game_players.each do |gp|
      user = gp.player
      broadcast_update_to("user_#{user.id}", target: "dashboard-my-games",
        partial: "dashboard/my_games", locals: { games: user.my_games.includes(game_players: :player) })
      broadcast_update_to("user_#{user.id}", target: "dashboard-completed-games",
        partial: "dashboard/completed_games", locals: { games: user.completed_games.includes(game_players: :player) })
    end
    User.where(approved: true).each do |user|
      broadcast_update_to("user_#{user.id}", target: "dashboard-waiting-games",
        partial: "dashboard/waiting_games", locals: { games: user.waiting_games.includes(game_players: :player) })
    end
  end

  def broadcast_game_update
    @board = nil # reset the board so we can re-construct it from the game state
    instantiate
    engine = TurnEngine.new(self)
    scores = live_scores

    # public stuff
    # - turn state
    broadcast_update_to( # first param is CHANNEL
      "game_#{id}",
      target: "turn-state",
      partial: "games/turn_state",
      locals: { game: self, engine: engine, my_turn: false }
    )
    # - resources
    broadcast_update_to(
      "game_#{id}",
      target: "common-resources",
      partial: "games/common_resources",
      locals: { game: self }
    )
    # - board/map
    broadcast_update_to(
      "game_#{id}",
      target: "board",
      partial: "games/board",
      locals: { game: self }
    )
    # - game log
    broadcast_update_to(
      "game_#{id}",
      target: "log",
      partial: "games/log",
      locals: { game: self }
    )
    # private stuff - each player
    game_players.each do |viewer|
      viewer.reload
      my_turn = viewer == current_player
      game_players.each do |displayed_player|
        displayed_player.reload
        broadcast_update_to(
          "game_player_#{viewer.id}_private", # player's private channel
          target: "game_player_#{displayed_player.id}",
          partial: "games/game_player",
          locals: {
            game: self,
            player: displayed_player,
            n: viewer == displayed_player ? 0 : 1,
            engine: engine,
            scores: scores
          }
        )
      end
      broadcast_update_to(
        "game_player_#{viewer.id}_private",
        target: "end-turn-area",
        partial: "games/end_turn",
        locals: { game: self, engine: engine, my_turn: my_turn, my_player: viewer }
      )
    end


    broadcast_dashboard_update
  end

  def capture_snapshot
    {
      "board_contents" => BoardState.dump(board_contents),
      "deck" => deck.dup,
      "discard" => discard.dup,
      "mandatory_count" => mandatory_count,
      "current_action" => current_action.deep_dup,
      "current_player_order" => current_player.order,
      "stone_walls" => stone_walls,
      "turn_number" => turn_number,
      "end_trigger_count" => end_trigger_count,
      "move_count" => move_count,
      "players" => game_players.map do |gp|
        { "order" => gp.order, "hand" => gp.hand,
          "supply" => gp.supply.dup, "tiles" => (gp.tiles || []).dup,
          "taken_from" => (gp.taken_from || []).dup,
          "bonus_scores" => gp.bonus_scores.dup }
      end
    }
  end

  def restore_snapshot!(snapshot)
    self.board_contents = BoardState.load(snapshot["board_contents"])
    self.deck = snapshot["deck"]
    self.discard = snapshot["discard"]
    self.current_action = snapshot["current_action"]
    self.mandatory_count = snapshot["mandatory_count"]
    self.stone_walls = snapshot["stone_walls"]
    self.turn_number = snapshot["turn_number"]
    self.end_trigger_count = snapshot["end_trigger_count"]
    self.move_count = snapshot["move_count"]
    self.current_player = game_players.find { |gp| gp.order == snapshot["current_player_order"] }

    snapshot["players"].each do |ps|
      gp = game_players.find { |g| g.order == ps["order"] }
      gp.update!(
        hand: ps["hand"], supply: ps["supply"], tiles: ps["tiles"],
        taken_from: ps["taken_from"], bonus_scores: ps["bonus_scores"]
      )
    end

    @board = nil # force re-instantiation of the read model
    save!
  end

  SOUND_KEY_FORMAT = /\A[a-z_]+\z/

  def broadcast_sound(key)
    return unless key&.match?(SOUND_KEY_FORMAT)
    Turbo::StreamsChannel.broadcast_render_to(
      "game_#{id}",
      inline: %(<turbo-stream action="play_sound" key="#{key}"></turbo-stream>)
    )
  end

  def board_has_quarry?
    board.map.any? { |s| s.location_hexes.any? { |h| h[:k] == "Quarry" } }
  end

  def next_card
    card = deck.shift
    shuffle_terrain_deck if deck.size < 1
    save
    card
  end

  def shuffle_terrain_deck
    discard_count = discard.size
    self.deck = discard.shuffle
    self.discard.clear
    self.move_count = (move_count || 0) + 1
    moves.build(
      order: move_count,
      action: "shuffle_discards",
      message: "Shuffled #{discard_count} discards into deck",
      deliberate: false,
      reversible: false
    )
    save
  end

  private

  def log_game_results
    ordered = game_players.order(:order).to_a
    score_line = ordered.map { |gp| "#{gp.player.handle} #{scores[gp.order.to_s]['total']}" }.join(", ")
    rating_line = ordered.map { |gp| "#{gp.player.handle} #{gp.rating_before} → #{gp.rating_after}" }.join(", ")
    self.move_count = (move_count || 0) + 1
    moves.create!(
      order: move_count,
      action: "game_results",
      message: "Scores: #{score_line}. Ratings: #{rating_line}",
      payload: {
        "scores" => scores,
        "ratings" => ordered.map { |gp| { "handle" => gp.player.handle, "rating_before" => gp.rating_before, "rating_after" => gp.rating_after } }
      },
      deliberate: false,
      reversible: false
    )
    save!
  end

  def select_boards(options = {})
    min = options[:min_board] || 0
    max = options[:max_board] || Boards::BoardSection::SECTIONS.size - 5 # last 4 are for testing UI
    self.boards = (min..max).to_a.sample(4).map { |id| [ id, rand(2) ] }
    while options[:include_boards] && !options[:include_boards].all? { |b| boards.any? { |bid, _| bid == b } }
      self.boards = (min..max).to_a.sample(4).map { |id| [ id, rand(2) ] }
    end
    self.move_count += 1
    moves.build(
      order: move_count,
      action: "select_boards",
      message: "Boards selected: #{boards.inspect}",
      payload: { "boards" => boards },
      deliberate: false,
      reversible: false
    )
    save
  end

  def populate_boards(options = {})
    state = BoardState.new
    instantiate
    placements = []
    @board.map.each_with_index do |board, i|
      board.location_hexes.each do |loc|
        # MVP (and base game) always have 2 tiles per location
        row, col = overall_location(i, loc[:r], loc[:c])
        klass = "#{loc[:k]}Tile"
        state.place_tile(row, col, klass, 2)
        placements << { row:, col:, klass:, qty: 2 }
      end
    end
    nomad_pool = Boards::Board::NOMAD_TILE_POOL.shuffle
    if options[:no_swords]
      nomad_pool.reject! { |t| t.include?("SwordTile") }
    end
    @board.map.each_with_index do |board_section, i|
      board_section.silver_hexes.select { |h| h[:k] == "Nomad" }.each do |nomad_hex|
        row, col = overall_location(i, nomad_hex[:r], nomad_hex[:c])
        klass = nomad_pool.shift
        next unless klass
        state.place_tile(row, col, klass, 1)
        placements << { row:, col:, klass:, qty: 1 }
      end
    end
    self.board_contents = state
    @board = nil # board was created before tiles were placed; reset so next instantiate is fresh
    Rails.logger.debug("CONTENT AT START: #{self.board_contents}")
    self.move_count = (move_count || 0) + 1
    moves.build(
      order: move_count,
      action: "populate_boards",
      message: "Tiles placed: #{placements.map { |p| "[#{p[:row]},#{p[:col]}] #{p[:klass]} x#{p[:qty]}" }.join(', ')}",
      payload: { "tiles" => placements },
      deliberate: false,
      reversible: false
    )
  end

  def initialize_terrain_deck
    self.discard = DECK.chars
    shuffle_terrain_deck
  end

  OPTIONAL_GOALS = %w[ambassadors citizens discoverers families farmers fishermen hermits knights merchants miners shepherds workers].freeze
  # OPTIONAL_GOALS = %w[citizens discoverers farmers fishermen hermits knights merchants miners workers].freeze
  TASKS = %w[advance compass_points fortress home_country place_of_refuge road].freeze
  CROSSROADS_BOARD_IDS = (12..15).to_a.freeze

  def select_goals
    instantiate
    castle_goal = board_has_castles? ? [ "castles" ] : []
    self.goals = castle_goal + OPTIONAL_GOALS.sample(3)
    @board = nil
    self.move_count = (move_count || 0) + 1
    moves.build(
      order: move_count,
      action: "select_goals",
      message: "Goals selected: #{goals.join(', ')}",
      payload: { "goals" => goals },
      deliberate: false,
      reversible: false
    )
    save
  end

  def select_tasks
    crossroads_count = boards.count { |id, _| CROSSROADS_BOARD_IDS.include?(id) }
    self.tasks = TASKS.sample(crossroads_count)
    if tasks.any?
      self.move_count = (move_count || 0) + 1
      moves.build(
        order: move_count,
        action: "select_tasks",
        message: "Tasks selected: #{tasks.join(', ')}",
        payload: { "tasks" => tasks },
        deliberate: false,
        reversible: false
      )
    end
    save
  end

  def board_has_castles?
    board.map.any? { |s| s.silver_hexes.any? { |h| h[:k] == "Castle" } }
  end

  def start_clocks
    return unless timed?
    bank_ms = SPEEDS.fetch(speed)[:bank_ms]
    game_players.each { |p| p.update(time_remaining_ms: bank_ms) }
    self.turn_started_at = Time.current
  end

  def populate_player_supplies
    game_players.each do |p|
      p.update(supply: { settlements: SETTLEMENTS_PER_PLAYER })
      p.update(tiles: [ { "klass" => "MandatoryTile", "used" => true } ])
    end
    # save no change to the game object
  end

  def deal_terrain_cards
    game_players.each do |p|
      p.update(hand: next_card)
    end
    save # update the deck
  end

  def choose_start_player
    game_players.shuffle.each_with_index { |p, n| p.update(order: n) }
    update(current_player: first_player)
    self.move_count = (move_count || 0) + 1
    moves.build(
      order: move_count,
      action: "choose_start_player",
      message: "Player order: #{game_players.order(:order).map { |gp| gp.player.handle }.join(', ')}",
      deliberate: false,
      reversible: false
    )
  end

  def overall_location(board, row, col)
    [ board / 2 * 10 + row, (board % 2) * 10 + col ]
  end

  def first_player
    game_players.where(order: 0).first
  end
end
