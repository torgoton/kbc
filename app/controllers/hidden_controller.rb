class HiddenController < ApplicationController
  def icons
    @game = Game.new
    @player = GamePlayer.first

    @game.state = "playing"
    @game.move_count = 0
    @game.mandatory_count = 3
    @game.boards = [
      [ 16, 0 ],
      [ 17, 0 ],
      [ 18, 0 ],
      [ 19, 0 ]
    ]
    @game.goals = %w[castles fishermen knights merchants]
    @game.current_player_id = @player.id
    @game.game_players = [ @player ]
    @game.scores = {}
    @game.deck = @game.discard = []

    @player.order = 0
    # @player.scores = {}

    # set up locations and tiles
    @game.send(:populate_boards)
    render :icons, locals: { game: @game, my_player: @player }
  end
end
