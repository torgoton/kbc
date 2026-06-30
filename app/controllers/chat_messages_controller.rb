class ChatMessagesController < ApplicationController
  def create
    @game = Game.find(params[:game_id])
    game_player = @game.game_players.find_by(player: Current.user)
    return head :forbidden unless game_player && !game_player.resigned? && @game.chat_open?

    @game.chat_messages.create(game_player: game_player, body: params[:body])
    head :no_content
  end
end
