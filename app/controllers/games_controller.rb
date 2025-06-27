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
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @game.errors, status: :unprocessable_entity }
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
    @game = Current.user.games.find(action_params[0])
    unless @game
      respond_to do |format|
        format.json { render json: { message: "Cannot find game" } }
      end
      return
    end

    target = action_params[1]
    row = target.match(/-\d*-/).to_s[1..-2].to_i
    col = target.match(/-\d*\z/).to_s[1..-1].to_i
    @game.build_settlement(row, col)
    respond_to do |format|
      format.html { redirect_to @game }
      format.turbo_stream { head :no_content }
    end
  end

  def end_turn
    Rails.logger.debug("END TURN action")
    @game = Current.user.games.find(params["id"].first)
    @game.end_turn if @game.mandatory_count <= 0
    respond_to do |format|
      format.html { redirect_to @game }
      format.turbo_stream { head :no_content }
    end
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

  private

  def action_params
    params.expect(:id, :build_cell)
  end

  def create_game_params
    { state: "waiting" }
  end
end
