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
    @game_players = @game.game_players
    Rails.logger.info("Me: #{Current.user.id}, CP:#{@game.current_player.player.id}")
    @my_turn = (@game.current_player.player == Current.user)
    @available = if @my_turn && (@game.mandatory_count > 0)
      @game.available_list(@game.current_player.order, @game.current_player.hand)
    else
      Array.new(20) { Array.new(20, false) }
    end
  end

  # BUILD action - move a piece from my supply to the board
  def build
    Rails.logger.info("BUILD PARAMS: #{build_params.inspect}")
    @game = Current.user.games.find(build_params[0])
    unless @game
      respond_to do |format|
        format.json { render json: { message: "Cannot find game" } }
      end
      return
    end
    unless @game.mandatory_count > 0
      respond_to do |format|
        format.json { render json: { message: "No moves left" } }
      end
      return
    end

    target = build_params[1]
    row = target.match(/-\d*-/).to_s[1..-2].to_i
    col = target.match(/-\d*\z/).to_s[1..-1].to_i
    # result = @game.build_settlement(row, col)
    # render : { message: result }
    @game.build_settlement(row, col)
    respond_to do |format|
      format.html { redirect_to @game }
      format.turbo_stream { nil }
    end
  end

  def end_turn
    Rails.logger.info("END TURN action")
    @game = Current.user.games.find(params["id"].first)
    @game.end_turn if @game.mandatory_count == 0
    redirect_to @game
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

  def build_params
    params.expect(:id, :build_cell)
  end

  def create_game_params
    { state: "waiting" }
  end
end
