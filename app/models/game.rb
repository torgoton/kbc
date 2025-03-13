class Game < ApplicationRecord
  STATES = [ "waiting", "playing", "completed" ]

  has_many :game_players
  has_many :players, through: :game_players
  has_one :first_player

  validates :state, inclusion: { in: STATES }

  attr_accessor :board_objects, :content_objects

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
    @board_objects = Board.new(JSON.parse(boards))
    @content_objects = Content.new(board_contents)
  end

  private

  def select_boards
    self.boards = [ [ "Tavern", 0 ], [ "Paddock", 0 ], [ "Oasis", 0 ], [ "Farm", 0 ] ].to_json
    save
  end

  def populate_boards
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
end
