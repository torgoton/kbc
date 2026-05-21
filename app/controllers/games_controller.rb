class GamesController < ApplicationController
  before_action :require_game_playing, only: [ :action, :select_action, :end_turn, :undo_move, :end_tile_action, :activate_outpost, :remove_settlement, :place_wall, :remove_meeple, :select_meeple, :activate_fort ]

  def new
    @game = Game.new
  end

  def create
    @game = Game.new(create_game_params)
    @game.add_player(Current.user)
    respond_to do |format|
      if @game.save
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

  def action
    return unless @game.game_players.find_by(player: Current.user) == @game.current_player

    Rails.logger.debug("TURN ACTION PARAMS: #{action_params.inspect}")

    @game.instantiate
    coord = Coordinate.new(action_params[:build_row], action_params[:build_col])
    apply_turn_action!(turn_action_for_click, row: coord.row, col: coord.col)
    respond_to do |format|
      format.html { head :no_content }
      format.turbo_stream { head :no_content }
    end
    animate_build_settlement(@game, @game.current_player, coord.row, coord.col)
    @game.broadcast_game_update
  end

  def select_action
    current_gp = @game.game_players.find_by(player: Current.user)
    return unless current_gp == @game.current_player
    apply_turn_action!(:select_action, tile: select_action_tile_klass)
    respond_to do |format|
      format.html { redirect_to @game }
      format.turbo_stream { head :no_content }
    end
    @game.broadcast_game_update
  end

  def end_turn
    Rails.logger.debug("END TURN action")
    current_gp = @game.game_players.find_by(player: Current.user)
    if current_gp == @game.current_player
      apply_turn_action!(:end_turn) if TurnViewAdapter.new(@game).turn_endable?
    end
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
    @game.add_player(Current.user)
    unless @game.save
      redirect_to dashboard_path, error: "Unable to join game"
      Rails.logger.error "ERROR saving game: #{@game.errors.inspect}"
      return
    end
    @game.start
    @game.broadcast_game_update
    redirect_to game_path(@game)
  end

  def undo_move
    Rails.logger.debug("UNDO MOVE action")
    ConsequenceApplier.unapply!(@game) if TurnViewAdapter.new(@game).undo_allowed?
    respond_to do |format|
      format.html { redirect_to @game }
      format.turbo_stream { head :no_content }
    end
    @game.broadcast_sound("undo")
    @game.broadcast_game_update
  end

  def end_tile_action
    current_gp = @game.game_players.find_by(player: Current.user)
    return unless current_gp == @game.current_player
    apply_turn_action!(:end_tile_action)
    respond_to do |format|
      format.html { redirect_to @game }
      format.turbo_stream { head :no_content }
    end
    @game.broadcast_game_update
  end

  def activate_outpost
    current_gp = @game.game_players.find_by(player: Current.user)
    return unless current_gp == @game.current_player
    apply_turn_action!(:activate_outpost)
    respond_to do |format|
      format.html { redirect_to @game }
      format.turbo_stream { head :no_content }
    end
    @game.broadcast_game_update
  end

  def activate_fort
    return unless @game.game_players.find_by(player: Current.user) == @game.current_player
    apply_turn_action!(:activate_fort)
    respond_to do |format|
      format.html { head :no_content }
      format.turbo_stream { head :no_content }
    end
    @game.broadcast_game_update
  end

  def remove_settlement
    current_gp = @game.game_players.find_by(player: Current.user)
    return unless current_gp == @game.current_player
    coord = Coordinate.new(action_params[:build_row], action_params[:build_col])
    apply_turn_action!(:remove_settlement, row: coord.row, col: coord.col)
    respond_to do |format|
      format.html { head :no_content }
      format.turbo_stream { head :no_content }
    end
    @game.broadcast_game_update
  end

  def place_wall
    current_gp = @game.game_players.find_by(player: Current.user)
    return unless current_gp == @game.current_player
    coord = Coordinate.new(action_params[:build_row], action_params[:build_col])
    apply_turn_action!(:place_wall, row: coord.row, col: coord.col)
    respond_to do |format|
      format.html { head :no_content }
      format.turbo_stream { head :no_content }
    end
    @game.broadcast_game_update
  end

  def remove_meeple
    return unless @game.game_players.find_by(player: Current.user) == @game.current_player
    coord = Coordinate.new(params[:row], params[:col])
    apply_turn_action!(:place_meeple, row: coord.row, col: coord.col)
    respond_to do |format|
      format.html { head :no_content }
      format.turbo_stream { head :no_content }
    end
    @game.broadcast_game_update
  end

  def select_meeple
    return unless @game.game_players.find_by(player: Current.user) == @game.current_player
    coord = Coordinate.new(params[:row], params[:col])
    apply_turn_action!(:place_meeple, row: coord.row, col: coord.col)
    respond_to do |format|
      format.html { head :no_content }
      format.turbo_stream { head :no_content }
    end
    @game.broadcast_game_update
  end

  private

  def require_game_playing
    @game = Current.user.games.find(params[:id])
    head :no_content unless @game.playing?
  end

  def action_params
    params.permit(:id, :build_row, :build_col)
  end

  def create_game_params
    { state: "waiting" }
  end

  def select_action_tile_klass
    type = params[:action_type].to_s
    type.end_with?("Tile") ? type : "#{type.camelize}Tile"
  end

  def turn_action_for_click
    sub_phase = Turn.from_game(@game).sub_phase
    case sub_phase
    when nil
      :build
    when Turn::SubPhases::SettlementMovePhase, Turn::SubPhases::ResettlementPhase
      sub_phase.source ? :move_settlement : :select_settlement
    when Turn::SubPhases::TargetedRemovalPhase
      :remove_settlement
    when Turn::SubPhases::WallPlacementPhase
      :place_wall
    when Turn::SubPhases::CityHallPhase
      :place_city_hall
    when Turn::SubPhases::MeeplePlacementPhase
      :place_meeple
    else
      :build
    end
  end

  def apply_turn_action!(action_name, **params)
    consequences = Turn.from_game(@game).handle(action_name, game: @game, **params)
    ConsequenceApplier.apply!(@game, consequences)
  rescue ConsequenceApplier::ApplyError => e
    Rails.logger.warn("Turn action rejected: #{e.message}")
    nil
  end
end
