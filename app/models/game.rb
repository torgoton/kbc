class Game < ApplicationRecord
  STATES = [ "waiting", "playing", "completed" ]
  SECTION_OFFSETS = [ [ 0, 0 ], [ 0, 10 ], [ 10, 0 ], [ 10, 10 ] ]
  DECK = "C" * 5 + "D" * 5 + "F" * 5 + "G" * 5 + "T" * 5
  ADJACENCIES = [ [ [ 0, -1 ], [ 0, 1 ], [ -1, -1 ], [ -1, 0 ], [ 1, -1 ], [ 1, 0 ] ],
                  [ [ 0, -1 ], [ 0, 1 ], [ -1,  0 ], [ -1, 1 ], [ 1,  0 ], [ 1, 1 ] ] ]
  MANDATORY_COUNT = 3

  # 10-10 adjacent to [[10,9], [10,11], [9,9], [9,10], [11,9], [11,10]]
  #  9-10 adjacent to [[9,9], [9,11], [8,10], [8,11], [10,10], [10,11]]

  has_many :game_players, dependent: :destroy
  has_many :players, through: :game_players, dependent: :delete_all
  belongs_to :current_player, class_name: "GamePlayer", optional: true

  validates :state, inclusion: { in: STATES }

  attr_accessor :board

  after_find do |_game|
    update(state: "waiting") unless state
  end

  # after_update_commit :broadcast_game_update

  def add_player(user)
    players << user
  end

  def playing?
    state.to_s == "playing"
  end

  def start
    select_boards
    populate_boards
    initialize_terrain_deck
    select_goals
    populate_player_supplies
    deal_terrain_cards
    choose_start_player
    self.state = "playing"
    save
  end

  def instantiate
    # Create objects from the serialized game state
    instantiate_boards
  end

  def instantiate_boards
    @board ||= Boards::Board.new(self)
  end

  def player_index_for(user)
    game_players.find { |p| p = user }.order
  end

  def available_list(order, terrain)
    available = Array.new(20) { Array.new(20, false) }
    any = false
    20.times do |row|
      20.times do |col|
        # Do I have a piece here?
        if board.content_at(row, col).try(:player) == order
          # mark the adjacent spots as available
          ADJACENCIES[row % 2].each do |r, c|
            if ((0..19).include?(row+r) && (0..19).include?(col+c)) && # spot is on the map
              board.content_at(row + r, col + c) == nil && # spot is empty
              board.terrain_at(row+r, col+c) == terrain # spot is of the correct terrain
              any = available[row+r][col+c] = true
            end
          end
        end
      end
    end
    return available if any
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
    return "Occupied" if board_contents["[#{row}, #{col}]"]
    # bail unless terrain matches card
    card_terrain = game_player.hand
    cell_terrain = board.terrain_at(row, col)
    log(" Terrain card is #{card_terrain}")
    log(" Terrain of cell is #{cell_terrain}")
    "Incorrect terrain" unless card_terrain == cell_terrain
    return "Not avilalable" unless available?(game_player.order, card_terrain, row, col)
    # actually build here
    game_player.supply["settlements"] -= 1
    board_contents["[#{row}, #{col}]"] = { "klass" => "Settlement", "player" => game_player.order }
    self.mandatory_count -= 1
    ActiveRecord::Base.transaction do
      game_player.save
      save
    end
  end

  def turn_endable?
    if (mandatory_count == 0) || current_player.supply["settlements"] == 0
      return true
    end
    false
  end

  def end_turn
    Rails.logger.debug("END TURN REQUESTED on GAME #{id}")
    Rails.logger.debug(" - current player #{current_player.inspect}")
    instantiate
    game_player = current_player
    self.discard.push(game_player.hand)
    game_player.hand = next_card
    self.mandatory_count = MANDATORY_COUNT
    next_order = (current_player.order + 1) % game_players.count
    Rails.logger.debug(" - next in order #{next_order}")
    self.current_player = game_players.find { |p| p.order == next_order }
    Rails.logger.debug(" - next player #{current_player.inspect}")
    ActiveRecord::Base.transaction do
      game_player.save
      save
    end
  end

  private

  # def broadcast_game_update
  #   instantiate
  #   broadcast_replace_to(
  #     "game_#{id}",
  #     target: "game_area",
  #     partial: "games/game",
  #     locals: { game: self }
  #   )
  # end

  def log(msg)
    Rails.logger.debug msg
  end

  # MVP: Always boards from "First Game"
  def select_boards
    self.boards = [ [ "Tavern", 0 ], [ "Paddock", 0 ], [ "Oasis", 0 ], [ "Farm", 0 ] ]
    save
  end

  def populate_boards
    contents = {}
    instantiate_boards
    @board.map.each_with_index do |board, i|
      board.location_hexes.each do |loc|
        # MVP (and base game) always have 2 tiles per location
        contents[overall_location(i, loc[:r], loc[:c])] = { klass: "#{loc[:k]}Tile", qty: 2 }
      end
    end
    self.board_contents = contents
    save
    Rails.logger.debug("CONTENT AT START: #{self.board_contents}")
  end

  def initialize_terrain_deck
    self.deck = DECK.chars.shuffle
    self.discard = []
    save
  end

  def shuffle_terrain_deck
    self.deck = discard.shuffle
  end

  def select_goals
    # MVP always these goals
    self.goals = [ "Fishermen", "Knights", "Merchants" ]
    save
  end

  def populate_player_supplies
    game_players.each do |p|
      p.update(supply: { settlements: 40 })
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
    update(mandatory_count: MANDATORY_COUNT)
  end

  def overall_location(board, row, col)
    [ SECTION_OFFSETS[board][0]+ row, SECTION_OFFSETS[board][1] + col ]
  end

  def first_player
    game_players.where(order: 1).first
  end

  def next_card
    shuffle_terrain_deck if deck.size < 1
    deck.shift
  end
end
