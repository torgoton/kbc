class Game < ApplicationRecord
  STATES = [ "waiting", "playing", "completed" ]
  OFFSETS = [ [ 0, 0 ], [ 0, 10 ], [ 10, 0 ], [ 10, 10 ] ]

  has_many :game_players
  has_many :players, through: :game_players
  has_one :first_player

  validates :state, inclusion: { in: STATES }

  attr_accessor :board

  after_find do |_game|
    update(state: "waiting") unless state
  end

  def add_player(user)
    players << user
  end

  def playing?
    state.to_s == "playing"
  end

  def start
    select_boards
    populate_boards
    shuffle_terrain_deck
    select_goals
    populate_player_supplies
    deal_terrain_cards
    choose_start_player
    save
    update(state: "playing")
  end

  def instantiate
    instantiate_boards
    instantiate_content
  end

  def instantiate_boards
    @board ||= Boards::Board.new(self)
  end

  def instantiate_content
  end

  private

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
        contents[overall_location(i, loc[:r], loc[:c])] = { klass: loc[:k], qty: 2 }
      end
    end
    self.board_contents = contents
    save
    Rails.logger.info("CONTENT AT START: #{self.board_contents}")
  end

  def shuffle_terrain_deck
  end

  def select_goals
  end

  def populate_player_supplies
  end

  def deal_terrain_cards
  end

  def choose_start_player
  end

  def overall_location(board, row, col)
    [ OFFSETS[board][0]+ row, OFFSETS[board][1] + col ]
  end

  # for console use during development
  def unplay
    # update(state: "waiting", board_contents: "[]", boards: "[]")
    # game_players.last.destroy
  end
end
