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
  end

  def join
    @game = Game.find(params[:id])
    unless @game
      redirect_to dashboard_path, notice: "Game not found"
      return
    end
    # Join and start the game
    @game.add_player(Current.user)
    unless @game.save
      redirect_to dashboard_path, error: "Unable to join game"
      Rails.logger.warn "ERROR saving game: #{@game.errors.inspect}"
      return
    end
    @game.start
    redirect_to game_path(@game)
  end

  private

  def create_game_params
    { state: "waiting" }
  end
end
