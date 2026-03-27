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
#  goals             :json
#  mandatory_count   :integer
#  move_count        :integer
#  scores            :json
#  state             :string
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

  def playing?
    state.to_s == "playing"
  end

  def waiting?
    state.to_s == "waiting"
  end

  def start(safe = true)
    if safe
      # Ensure we have at least 2 players
      if game_players.count < 2
        Rails.logger.warn "Cannot start game with less than 2 players"
        return false
      end
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
    select_boards
    populate_boards
    initialize_terrain_deck
    select_goals
    populate_player_supplies
    deal_terrain_cards
    choose_start_player
    self.current_action = { "type" => "mandatory" }
    self.base_snapshot = capture_snapshot
    save
  end

  def instantiate
    # Create objects from the serialized game state
    instantiate_board
  end

  def instantiate_board
    @board ||= Boards::Board.new(self)
  end

  def player_index_for(user)
    game_players.find { |p| p = user }.order
  end

  def available_list(active_player, terrain)
    return nil unless playing?
    available = Array.new(20) { Array.new(20, false) }

    # first pass: look for pieces belonging to active player
    any = false
    20.times do |row|
      20.times do |col|
        # Do I have a piece here?
        if board.content_at(row, col).try(:player) == active_player
          # mark the adjacent spots as available
          board_contents.neighbors(row, col).each do |nr, nc|
            if board.content_at(nr, nc) == nil && board.terrain_at(nr, nc) == terrain
              any = available[nr][nc] = true
            end
          end
        end
      end
    end
    return available if any

    # second pass: no pieces found, so look for any matching terrain
    20.times do |row|
      20.times do |col|
        if board.terrain_at(row, col) == terrain
          available[row][col] = true unless board.content_at(row, col)
        end
      end
    end
    available
  end

  def available?(order, terrain, row, col)
    @list ||= available_list(order, terrain)
    @list.any? ? @list[row][col] : true
  end

  def build_settlement(row, col)
    log("Attempt to build at #{row}, #{col}")
    instantiate
    # bail if no pieces left
    game_player = current_player
    settlements = game_player.supply["settlements"]
    log(" I have #{settlements} settlements remaining")
    return "No settlements left" if settlements < 1
    # bail if occupied
    # return "Occupied" if board_contents["[#{row}, #{col}]"]
    # bail unless terrain matches card
    card_terrain = game_player.hand
    # cell_terrain = board.terrain_at(row, col)
    # log(" Terrain card is #{card_terrain}")
    # log(" Terrain of cell is #{cell_terrain}")
    # "Incorrect terrain" unless card_terrain == cell_terrain
    # bail unless available
    return "Not avilalable" unless available?(game_player.order, card_terrain, row, col)
    # actually build here
    self.move_count += 1
    # - create a Move record (deliberate)
    self.moves.create(
      order: self.move_count,
      game_player: game_player,
      deliberate: true,
      action: "build",
      from: "supply",
      to: "[#{row}, #{col}]",
      reversible: true,
      payload: { "card" => card_terrain },
      message: "#{game_player.player.handle} built a settlement on #{Boards::Board::TERRAIN_NAMES[card_terrain]}"
    )
    # - update supply
    game_player.supply["settlements"] -= 1
    # - update board_contents
    board_contents_will_change!
    board_contents.place_settlement(row, col, game_player.order)
    self.mandatory_count -= 1
    log("Building settlement at #{row}, #{col} for player #{game_player.order}")
    # - apply consequential tile pickup if adjacent to a location hex with tiles
    #   (this increments move_count and creates its own Move record)
    apply_tile_pickup(game_player, row, col)
    game_player.save
    save
  end

  def select_action(type)
    self.move_count += 1
    self.moves.create(
      order: move_count,
      game_player: current_player,
      deliberate: true,
      action: "select_action",
      to: type,
      reversible: true,
      message: "#{current_player.player.handle} selected the #{type} action"
    )
    self.current_action = { "type" => type }
    save
  end

  def select_settlement(row, col)
    self.move_count += 1
    self.moves.create(
      order: move_count,
      game_player: current_player,
      deliberate: true,
      action: "select_settlement",
      from: "[#{row}, #{col}]",
      reversible: true,
      message: "#{current_player.player.handle} selected a settlement at [#{row}, #{col}]"
    )
    self.current_action = current_action.merge("from" => "[#{row}, #{col}]")
    save
  end

  def move_settlement(row, col)
    instantiate
    from = current_action["from"]
    from_coord = Coordinate.from_key(from)
    self.move_count += 1
    self.moves.create(
      order: move_count,
      game_player: current_player,
      deliberate: true,
      action: "move_settlement",
      from: from,
      to: Coordinate.new(row, col).to_key,
      reversible: true,
      message: "#{current_player.player.handle} moved a settlement to [#{row}, #{col}]"
    )
    board_contents_will_change!
    board_contents.move_settlement(*from_coord, row, col)
    self.current_action = { "type" => "mandatory" }
    tiles = current_player.tiles || []
    idx = tiles.index { |t| t["klass"] == "PaddockTile" && t["used"] == false }
    if idx
      updated = tiles.dup
      updated[idx] = updated[idx].merge("used" => true)
      current_player.tiles = updated
    end
    apply_tile_forfeit(current_player)
    apply_tile_pickup(current_player, row, col)
    current_player.save
    save
  end

  def build_on_desert(row, col)
    instantiate
    game_player = current_player
    return "No settlements left" if game_player.supply["settlements"] < 1
    destinations = Tiles::OasisTile.new(0).valid_destinations(
      board_contents: board_contents,
      board: @board,
      player_order: game_player.order
    )
    return "Not available" unless destinations.include?([ row, col ])
    self.move_count += 1
    self.moves.create(
      order: move_count,
      game_player: game_player,
      deliberate: true,
      action: "build_oasis",
      from: "supply",
      to: "[#{row}, #{col}]",
      reversible: true,
      message: "#{game_player.player.handle} built a settlement on Desert"
    )
    game_player.supply["settlements"] -= 1
    board_contents_will_change!
    board_contents.place_settlement(row, col, game_player.order)
    self.current_action = { "type" => "mandatory" }
    tiles = game_player.tiles || []
    idx = tiles.index { |t| t["klass"] == "OasisTile" && t["used"] == false }
    if idx
      updated = tiles.dup
      updated[idx] = updated[idx].merge("used" => true)
      game_player.tiles = updated
    end
    apply_tile_pickup(game_player, row, col)
    game_player.save
    save
  end

  def tile_activatable?(tile)
    return false if tile["used"]
    return false unless mandatory_count == MANDATORY_COUNT || mandatory_count <= 0 ||
      current_player.supply["settlements"] == 0
    instantiate
    ctx = { player_order: current_player.order, board_contents: board_contents, board: @board }
    Tiles::Tile.from_hash(tile).activatable?(**ctx)
  end

  def turn_endable?
    current_action["type"] == "mandatory" &&
      (mandatory_count <= 0 || current_player.supply["settlements"] == 0)
  end

  def undo_allowed?
    last_move = moves.where(deliberate: true).order(order: :desc).first
    return false unless last_move
    last_move.reversible
  end

  def turn_state
    case current_action["type"]
    when "paddock"
      "#{current_player.player.handle} must move a settlement"
    when "oasis"
      "#{current_player.player.handle} must build on a Desert space"
    else
      if mandatory_count > 0 && current_player.supply["settlements"] > 0
        "#{current_player.player.handle} must build " \
        "#{ActionController::Base.helpers.pluralize(mandatory_count, "settlement")} on " \
        "#{Boards::Board::TERRAIN_NAMES[current_player.hand]}"
      else
        "#{current_player.player.handle} must end their turn"
      end
    end
  end

  def end_turn
    Rails.logger.debug("END TURN REQUESTED on GAME #{id}")
    Rails.logger.debug(" - current player #{current_player.inspect}")
    instantiate
    game_player = current_player
    card_discarded = game_player.hand
    self.discard.push(game_player.hand)
    game_player.hand = next_card
    card_drawn = game_player.hand
    reshuffled = self.discard.empty?
    self.mandatory_count = MANDATORY_COUNT
    self.current_action = { "type" => "mandatory" }
    next_order = (current_player.order + 1) % game_players.count
    Rails.logger.debug(" - next in order #{next_order}")
    self.current_player = game_players.find { |p| p.order == next_order }
    Rails.logger.debug(" - next player #{current_player.inspect}")
    if current_player.tiles
      current_player.tiles = current_player.tiles.map { |t| t.merge("used" => false) }
    end
    self.move_count += 1
    # - create a Move record
    self.moves.create(
      order: self.move_count,
      game_player: game_player,
      deliberate: true,
      action: "end_turn",
      reversible: false,
      payload: { "card_discarded" => card_discarded, "card_drawn" => card_drawn,
                 "reshuffled" => reshuffled, "deck_after" => self.deck.dup },
      message: "#{game_player.player.handle} ended their turn"
    )
    ActiveRecord::Base.transaction do
      game_player.save
      current_player.save
      save
    end
  end

  def undo_last_move
    last_deliberate = moves.where(deliberate: true).order(order: :desc).first
    return unless last_deliberate
    Rails.logger.debug("UNDOING back to deliberate move #{last_deliberate.inspect}")
    instantiate
    # Undo all moves since (and including) the last deliberate one, in reverse order
    moves.where("id >= ?", last_deliberate.id).order(id: :desc).each do |move|
      Rails.logger.debug("  undoing #{move.action} (order #{move.order})")
      self.move_count -= 1
      case move.action
      when "build"
        self.mandatory_count += 1
        board_contents_will_change!
        board_contents.remove(*Coordinate.from_key(move.to))
        move.game_player.supply["settlements"] += 1
        move.game_player.save
      when "build_oasis"
        board_contents_will_change!
        board_contents.remove(*Coordinate.from_key(move.to))
        move.game_player.supply["settlements"] += 1
        tiles = move.game_player.tiles || []
        idx = tiles.index { |t| t["klass"] == "OasisTile" && t["used"] == true }
        if idx
          updated = tiles.dup
          updated[idx] = updated[idx].merge("used" => false)
          move.game_player.tiles = updated
          move.game_player.save
        end
        self.current_action = { "type" => "oasis" }
      when "move_settlement"
        board_contents_will_change!
        board_contents.move_settlement(*Coordinate.from_key(move.to), *Coordinate.from_key(move.from))
        self.current_action = { "type" => "paddock", "from" => move.from }
        tiles = move.game_player.tiles || []
        idx = tiles.index { |t| t["klass"] == "PaddockTile" && t["used"] == true }
        if idx
          updated = tiles.dup
          updated[idx] = updated[idx].merge("used" => false)
          move.game_player.tiles = updated
          move.game_player.save
        end
      when "select_action"
        self.current_action = { "type" => "mandatory" }
      when "select_settlement"
        current_action_will_change!
        current_action.delete("from")
      when "pick_up_tile"
        # Return the tile to its location (qty was decremented, never deleted)
        board_contents_will_change!
        board_contents.increment_tile(*Coordinate.from_key(move.from))
        # Remove the tile from the player's collection
        tiles = move.game_player.tiles || []
        move.game_player.tiles = tiles.reject { |t| t["from"] == move.from }
        move.game_player.save
      when "forfeit_tile"
        klass = move.payload["klass"]
        tiles = move.game_player.tiles || []
        move.game_player.tiles = tiles + [ { "klass" => klass, "from" => move.from, "used" => move.to == "true" } ]
        move.game_player.save
      end
      move.destroy
    end
    save
  end

  def broadcast_game_update
    @board = nil # reset the board so we can re-construct it from the game state
    instantiate

    # public stuff
    # - turn state
    broadcast_update_to( # first param is CHANNEL
      "game_#{id}",
      target: "turn-state",
      partial: "games/turn_state",
      locals: { game: self }
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
        locals: { game: self, player: gp, n: 1 }
      )
    end

    # private stuff - each player
    game_players.each do |gp|
      gp.reload
      broadcast_update_to(
        "game_player_#{gp.id}_private", # player's private channel
        target: "game_player_#{gp.id}",
        partial: "games/game_player",
        locals: { game: self, player: gp, n: 0 }
      )
    end

    # - timestamp - MUST be last change
    broadcast_update_later_to(
      "game_#{id}",
      target: "last-updated-at",
      partial: "games/last_updated_at",
      locals: { move_count: move_count }
    )
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
      "players" => game_players.map do |gp|
        { "order" => gp.order, "hand" => gp.hand,
          "supply" => gp.supply.dup, "tiles" => (gp.tiles || []).dup }
      end
    }
  end

  def replayed_state
    GameReplayer.new(self).replay
  end

  private

  def log(msg)
    Rails.logger.debug msg
  end

  # Remove any tiles the player holds whose location hex is no longer adjacent
  # to any of their settlements (called after a Paddock move).
  def apply_tile_forfeit(game_player)
    return if (game_player.tiles || []).empty?
    game_player.tiles = game_player.tiles.reject do |tile|
      loc = tile["from"]
      next false unless loc
      loc_coord = Coordinate.from_key(loc)
      should_forfeit = board_contents.settlements_for(game_player.order).none? do |s_row, s_col|
        board_contents.neighbors(s_row, s_col).any? { |nr, nc| Coordinate.new(nr, nc).to_key == loc }
      end
      if should_forfeit && board_contents.tile_klass(*loc_coord)
        klass = board_contents.tile_klass(*loc_coord)
        self.move_count += 1
        self.moves.create(
          order: move_count,
          game_player: game_player,
          deliberate: false,
          action: "forfeit_tile",
          reversible: true,
          from: loc,
          to: tile["used"].to_s,
          payload: { "klass" => klass },
          message: "#{game_player.player.handle} forfeited a #{klass.delete_suffix('Tile').downcase} tile"
        )
      end
      should_forfeit
    end
  end

  # Check whether building at (row, col) should trigger a tile pickup.
  # Returns { key:, klass: } if a tile is available at an adjacent location
  # the player doesn't already hold, or nil otherwise.
  def find_tile_pickup(game_player, row, col)
    held_locations = (game_player.tiles || []).map { |t| t["from"] }.to_set
    board_contents.neighbors(row, col).each do |adj_r, adj_c|
      klass = board_contents.tile_klass(adj_r, adj_c)
      next unless klass && board_contents.tile_qty(adj_r, adj_c) > 0
      tile_key = Coordinate.new(adj_r, adj_c).to_key
      next if held_locations.include?(tile_key)
      return { key: tile_key, klass: klass }
    end
    nil
  end

  # Create a consequential "pick_up_tile" move and update state accordingly.
  def apply_tile_pickup(game_player, row, col)
    tile = find_tile_pickup(game_player, row, col)
    return unless tile

    qty_before = board_contents.tile_qty(*Coordinate.from_key(tile[:key]))
    self.move_count += 1
    self.moves.create(
      order: move_count,
      game_player: game_player,
      deliberate: false,
      action: "pick_up_tile",
      from: tile[:key],
      to: "player_#{game_player.order}",
      reversible: true,
      payload: { "klass" => tile[:klass], "qty_before" => qty_before },
      message: "#{game_player.player.handle} picked up a #{tile[:klass].delete_suffix('Tile')} tile"
    )
    # Decrement qty in place; entry remains even when qty reaches 0
    board_contents_will_change!
    board_contents.decrement_tile(*Coordinate.from_key(tile[:key]))
    # Add to player's tile collection, tracking which location it came from
    game_player.tiles = (game_player.tiles || []) + [ { "klass" => tile[:klass], "from" => tile[:key], "used" => true } ]
  end

  # MVP: Always boards from "First Game"
  def select_boards
    self.boards = [ [ "Tavern", 0 ], [ "Paddock", 0 ], [ "Oasis", 0 ], [ "Farm", 0 ] ]
    save
  end

  def populate_boards
    state = BoardState.new
    instantiate_board
    @board.map.each_with_index do |board, i|
      board.location_hexes.each do |loc|
        # MVP (and base game) always have 2 tiles per location
        row, col = overall_location(i, loc[:r], loc[:c])
        state.place_tile(row, col, "#{loc[:k]}Tile", 2)
      end
    end
    update(board_contents: state)
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

  def select_goals
    # MVP always these goals
    self.goals = [ "Fishermen", "Knights", "Merchants" ]
    save
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
