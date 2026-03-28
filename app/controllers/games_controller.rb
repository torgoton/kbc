class GamesController < ApplicationController
  def new
    @game = Game.new
  end

  def create
    @game = Game.new(create_game_params)
    @game.add_player(Current.user)
    respond_to do |format|
      if @game.save
        format.html { redirect_to dashboard_path, notice: "Game created" }
        format.json { render :show, status: :created, location: @game }
      else
        format.html { render :new, status: :unprocessable_content }
        format.json { render json: @game.errors, status: :unprocessable_content }
      end
    end
  end

  def show
    @game = Game.find(params[:id])
    @game.instantiate
    @my_player = @game.game_players.find { |gp| gp.player == Current.user }
    render :show, locals: { game: @game, my_player: @my_player }
  end

  # ACTION - do a part of a turn by a player. Either
  # 1. move a piece from the board to my supply as part of the mandatory action
  # 2. use a tile that I have to build a settlement on the board
  # 3. use a tile that I have to move a piece on the board
  def action
    Rails.logger.debug("TURN ACTION PARAMS: #{action_params.inspect}")
    @game = Current.user.games.find(action_params[:id])
    unless @game
      respond_to do |format|
        format.json { render json: { message: "Cannot find game" } }
      end
      return
    end

    coord = Coordinate.new(action_params[:build_row], action_params[:build_col])
    engine = TurnEngine.new(@game)
    case @game.current_action["type"]
    when "paddock"
      if @game.current_action["from"]
        engine.move_settlement(coord.row, coord.col)
      else
        engine.select_settlement(coord.row, coord.col)
      end
    when "oasis"
      engine.activate_tile_build(coord.row, coord.col)
    else
      engine.build_settlement(coord.row, coord.col)
    end
    respond_to do |format|
      format.html { head :no_content }
      format.turbo_stream { head :no_content }
    end
    animate_build_settlement(@game, @game.current_player, coord.row, coord.col)
    # update all clients
    @game.broadcast_game_update
  end

  def select_action
    @game = Current.user.games.find(params[:id])
    TurnEngine.new(@game).select_action(params[:action_type])
    respond_to do |format|
      format.html { redirect_to @game }
      format.turbo_stream { head :no_content }
    end
    @game.broadcast_game_update
  end

  def end_turn
    Rails.logger.debug("END TURN action")
    @game = Current.user.games.find(params[:id])
    current_gp = @game.game_players.find_by(player: Current.user)
    engine = TurnEngine.new(@game)
    engine.end_turn if current_gp == @game.current_player && engine.turn_endable?
    respond_to do |format|
      format.html { redirect_to @game }
      format.turbo_stream { head :no_content }
    end
    @game.broadcast_game_update
  end

  def join
    @game = Game.find(params[:id])
    unless @game
      redirect_to dashboard_path, notice: "Game not found"
      return
    end
    # Join the game
    @game.add_player(Current.user)
    unless @game.save
      redirect_to dashboard_path, error: "Unable to join game"
      Rails.logger.warn "ERROR saving game: #{@game.errors.inspect}"
      return
    end
    # MVP: 2 players every game, so just start it now
    @game.start
    redirect_to game_path(@game)
  end

  def undo_move
    Rails.logger.debug("UNDO MOVE action")
    @game = Current.user.games.find(params[:id])
    engine = TurnEngine.new(@game)
    engine.undo_last_move if engine.undo_allowed?
    respond_to do |format|
      format.html { redirect_to @game }
      format.turbo_stream { head :no_content }
    end
    @game.broadcast_game_update
  end

  private

  def action_params
    params.permit(:id, :build_row, :build_col)
  end

  def create_game_params
    { state: "waiting" }
  end
end
