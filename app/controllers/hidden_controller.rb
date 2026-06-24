class HiddenController < ApplicationController
  def icons
    @game = Game.new

    @game.state = "completed"
    @game.move_count = 0
    @game.mandatory_count = 3
    @game.boards = [
      [ 16, 0 ],
      [ 17, 0 ],
      [ 18, 0 ],
      [ 19, 0 ]
    ]
    @game.goals = %w[castles fishermen knights merchants]
    @game.current_player_id = nil
    @game.scores = {}
    @game.deck = @game.discard = []
    @game.mandatory_count = 0

    # set up locations and tiles
    @game.send(:populate_boards)
    @game.instantiate_board
    render :icons, locals: { game: @game, my_player: @player }
  end
end
