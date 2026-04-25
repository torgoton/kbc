# == Schema Information
#
# Table name: games
#
#  id                :bigint           not null, primary key
#  base_snapshot     :jsonb
#  board_contents    :json
#  boards            :json
#  current_action    :json
#  deck              :json
#  discard           :json
#  ending            :boolean          default(FALSE), not null
#  goals             :json
#  mandatory_count   :integer
#  move_count        :integer
#  scores            :json
#  state             :string
#  stone_walls       :integer          default(25), not null
#  tasks             :json
#  turn_number       :integer          default(0), not null
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

  has_many :game_players, dependent: :destroy
  has_many :players, through: :game_players, dependent: :delete_all
  has_many :moves, dependent: :destroy
  belongs_to :current_player, class_name: "GamePlayer", optional: true

  serialize :board_contents, coder: BoardState

  validates :state, inclusion: { in: STATES }

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
    end
    self.moves.destroy_all
    self.state = "playing"
    self.move_count = 0
    self.mandatory_count = MANDATORY_COUNT
    select_boards(options)
    populate_boards(options)
    initialize_terrain_deck
    select_goals
    select_tasks
    populate_player_supplies
    deal_terrain_cards
    choose_start_player
    self.current_action = { "type" => "mandatory" }
    self.base_snapshot = capture_snapshot
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
    ending == true
  end

  def turn_state
    return "Waiting for players" if waiting?
    TurnEngine.new(self).turn_state
  end

  def my_turn?(user)
    playing? && current_player&.player == user
  end

  def player_handles
    game_players.map { |gp| gp.player.handle }.join(", ")
  end

  def live_scores
    Scoring.new(self).compute
  end

  def complete!
    self.state = "completed"
    self.scores = Scoring.new(self).compute
    save!
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
    return [] if scores.blank?
    max_total = scores.values.map { |s| s["total"] }.max
    game_players.select { |gp| scores[gp.order.to_s]["total"] == max_total }
  end

  def instantiate
    # Create objects from the serialized game state
    instantiate_board
  end

  def instantiate_board
    @board ||= Boards::Board.new(self)
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
    # - each player
    game_players.each do |gp|
      broadcast_update_to(
        "game_#{id}",
        target: "game_player_#{gp.id}",
        partial: "games/game_player",
        locals: { game: self, player: gp, n: 1, engine: engine, scores: scores }
      )
    end

    # private stuff - each player
    game_players.each do |gp|
      gp.reload
      my_turn = gp == current_player
      broadcast_update_to(
        "game_player_#{gp.id}_private", # player's private channel
        target: "game_player_#{gp.id}",
        partial: "games/game_player",
        locals: { game: self, player: gp, n: 0, engine: engine, scores: scores }
      )
      broadcast_update_to(
        "game_player_#{gp.id}_private",
        target: "end-turn-area",
        partial: "games/end_turn",
        locals: { game: self, engine: engine, my_turn: my_turn }
      )
    end


    broadcast_dashboard_update
  end

  def capture_snapshot
    {
      "board_contents" => BoardState.dump(board_contents),
      "boards" => boards.dup,
      "deck" => deck.dup,
      "discard" => discard.dup,
      "goals" => goals&.dup,
      "mandatory_count" => mandatory_count,
      "current_action" => current_action.dup,
      "current_player_order" => current_player.order,
      "stone_walls" => stone_walls,
      "turn_number" => turn_number,
      "players" => game_players.map do |gp|
        { "order" => gp.order, "hand" => gp.hand,
          "supply" => gp.supply.dup, "tiles" => (gp.tiles || []).dup,
          "taken_from" => (gp.taken_from || []).dup }
      end
    }
  end

  SOUND_KEY_FORMAT = /\A[a-z_]+\z/

  def broadcast_sound(key)
    return unless key&.match?(SOUND_KEY_FORMAT)
    Turbo::StreamsChannel.broadcast_render_to(
      "game_#{id}",
      inline: %(<turbo-stream action="play_sound" key="#{key}"></turbo-stream>)
    )
  end

  def replayed_state
    GameReplayer.new(self).replay
  end

  def board_has_quarry?
    board.map.any? { |s| s.location_hexes.any? { |h| h[:k] == "Quarry" } }
  end

  private

  def select_boards(options = {})
    min = options[:min_board] || 0
    max = options[:max_board] || Boards::BoardSection::SECTIONS.size - 1
    self.boards = (min..max).to_a.sample(4).map { |id| [ id, rand(2) ] }
    while options[:include_boards] && !options[:include_boards].all? { |b| boards.any? { |bid, _| bid == b } }
      self.boards = (min..max).to_a.sample(4).map { |id| [ id, rand(2) ] }
    end
    save
  end

  def populate_boards(options = {})
    state = BoardState.new
    instantiate_board
    @board.map.each_with_index do |board, i|
      board.location_hexes.each do |loc|
        # MVP (and base game) always have 2 tiles per location
        row, col = overall_location(i, loc[:r], loc[:c])
        state.place_tile(row, col, "#{loc[:k]}Tile", 2)
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
        state.place_tile(row, col, klass, 1) if klass
      end
    end
    update(board_contents: state)
    @board = nil # board was created before tiles were placed; reset so next instantiate is fresh
    Rails.logger.debug("CONTENT AT START: #{self.board_contents}")
  end

  def initialize_terrain_deck
    self.discard = DECK.chars
    shuffle_terrain_deck
  end

  def shuffle_terrain_deck
    self.deck = discard.shuffle
    self.discard.clear
    save
  end

  OPTIONAL_GOALS = %w[ambassadors citizens discoverers families farmers fishermen hermits knights merchants miners shepherds workers].freeze
  TASKS = %w[advance compass_points fortress home_country place_of_refuge road].freeze
  CROSSROADS_BOARD_IDS = (12..15).to_a.freeze

  def select_goals
    instantiate_board
    castle_goal = board_has_castles? ? [ "castles" ] : []
    self.goals = castle_goal + OPTIONAL_GOALS.sample(3)
    @board = nil
    save
  end

  def select_tasks
    crossroads_count = boards.count { |id, _| CROSSROADS_BOARD_IDS.include?(id) }
    self.tasks = TASKS.sample(crossroads_count)
    save
  end

  def board_has_castles?
    board.map.any? { |s| s.silver_hexes.any? { |h| h[:k] == "Castle" } }
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
  end

  def overall_location(board, row, col)
    [ board / 2 * 10 + row, (board % 2) * 10 + col ]
  end

  def first_player
    game_players.where(order: 0).first
  end

  def next_card
    card = deck.shift
    shuffle_terrain_deck if deck.size < 1
    save
    card
  end
end
