class GamesController < ApplicationController
  before_action :require_game_playing, only: [ :action, :select_action, :end_turn, :undo_move, :end_tile_action, :activate_outpost, :remove_meeple, :select_meeple, :activate_fort ]
  # ponytail: undo_move intentionally excluded — it was never current-player-gated at baseline.
  # Whether a non-current player should be able to undo is an open question tracked as a follow-up.
  before_action :require_current_player, only: [ :action, :select_action, :end_turn, :end_tile_action, :activate_outpost, :remove_meeple, :select_meeple, :activate_fort ]
  after_action :broadcast_game_update, only: [ :action, :select_action, :end_turn, :undo_move, :end_tile_action, :activate_outpost, :remove_meeple, :select_meeple, :activate_fort ]

  def new
    @game = Game.new
  end

  def create
    @game = Game.new(create_game_params)
    @game.add_player(Current.user)
    respond_to do |format|
      if @game.save
        log_table_opened
        @game.broadcast_dashboard_update
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
    TurnEngine.new(@game).click(
      Coordinate.new(action_params[:build_row], action_params[:build_col])
    )
    respond_to do |format|
      format.html { head :no_content }
      format.turbo_stream { head :no_content }
    end
  end

  def select_action
    TurnEngine.new(@game).select_action(params[:action_type])
    respond_to do |format|
      format.html { redirect_to @game }
      format.turbo_stream { head :no_content }
    end
  end

  def end_turn
    Rails.logger.debug("END TURN action")
    engine = TurnEngine.new(@game)
    engine.end_turn if engine.turn_endable?
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
      Rails.logger.error "ERROR saving game: #{@game.errors.inspect}"
      return
    end
    log_table_joined
    # MVP: 2 players every game, so just start it now
    @game.start
    @game.broadcast_game_update
    redirect_to game_path(@game)
  end

  def undo_move
    Rails.logger.debug("UNDO MOVE action")
    engine = TurnEngine.new(@game)
    engine.undo_last_move if engine.undo_allowed?
    respond_to do |format|
      format.html { redirect_to @game }
      format.turbo_stream { head :no_content }
    end
    @game.broadcast_sound("undo")
  end

  def end_tile_action
    TurnEngine.new(@game).end_tile_action
    respond_to do |format|
      format.html { redirect_to @game }
      format.turbo_stream { head :no_content }
    end
  end

  def activate_outpost
    TurnEngine.new(@game).activate_outpost
    respond_to do |format|
      format.html { redirect_to @game }
      format.turbo_stream { head :no_content }
    end
  end

  def activate_fort
    TurnEngine.new(@game).activate_fort_tile
    respond_to do |format|
      format.html { head :no_content }
      format.turbo_stream { head :no_content }
    end
  end

  def remove_meeple
    coord = Coordinate.new(params[:row], params[:col])
    TurnEngine.new(@game).remove_meeple_action(coord.row, coord.col)
    respond_to do |format|
      format.html { head :no_content }
      format.turbo_stream { head :no_content }
    end
  end

  def select_meeple
    coord = Coordinate.new(params[:row], params[:col])
    TurnEngine.new(@game).select_meeple_for_move(coord.row, coord.col)
    respond_to do |format|
      format.html { head :no_content }
      format.turbo_stream { head :no_content }
    end
  end

  def resign
    game = Game.find(params[:id])
    game_player = game.game_players.find_by(player: Current.user)
    game_player&.resign!(message: "#{game_player.player.handle} resigned", deliberate: true)
    redirect_to game_path(game)
  end

  # An opponent claims victory once the current player's clock has flagged
  # (server-side check via Game#claimable_by? — never trust the client).
  def claim_victory
    game = Game.find(params[:id])
    if game.claimable_by?(Current.user)
      flagged_player = game.current_player
      claimant = game.game_players.find_by(player: Current.user)
      flagged_player.resign!(
        message: "#{flagged_player.player.handle} ran out of time — #{claimant.player.handle} claimed victory",
        deliberate: true
      )
    end
    redirect_to game_path(game)
  end

  private

  def log_table_opened
    game_player = @game.game_players.find_by(player: Current.user)
    @game.move_count = (@game.move_count || 0) + 1
    @game.moves.create!(
      order: @game.move_count,
      game_player: game_player,
      action: "open_table",
      message: "#{game_player.player.handle} opened the table",
      deliberate: true,
      reversible: false
    )
    @game.move_count += 1
    @game.moves.create!(
      order: @game.move_count,
      action: "game_options",
      message: "Game options: #{game_options_message}",
      deliberate: true,
      reversible: false
    )
    @game.save!
  end

  def game_options_message
    return "Untimed" unless @game.timed?
    speed = Game::SPEEDS.fetch(@game.speed)
    "#{@game.speed.capitalize} (#{speed[:bank_ms] / 60_000} min + #{speed[:increment_ms] / 1_000} s/turn)"
  end

  def log_table_joined
    game_player = @game.game_players.find_by(player: Current.user)
    @game.move_count = (@game.move_count || 0) + 1
    @game.moves.create!(
      order: @game.move_count,
      game_player: game_player,
      action: "join_table",
      message: "#{game_player.player.handle} joined the table",
      deliberate: true,
      reversible: false
    )
    @game.save!
  end

  def require_game_playing
    @game = Current.user.games.find(params[:id])
    head :no_content unless @game.playing?
  end

  def require_current_player
    head :no_content unless @game.game_players.find_by(player: Current.user) == @game.current_player
  end

  def broadcast_game_update
    @game.broadcast_game_update
  end

  def action_params
    params.permit(:id, :build_row, :build_col)
  end

  def create_game_params
    { state: "waiting", speed: params.fetch(:game, {}).permit(:speed)[:speed].presence }
  end
end
