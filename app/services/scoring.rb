class Scoring
  GOAL_CLASSES = {
    "ambassadors" => Scoring::Goals::Ambassadors,
    "castles"     => Scoring::Goals::Castles,
    "citizens"    => Scoring::Goals::Citizens,
    "discoverers" => Scoring::Goals::Discoverers,
    "families"    => Scoring::Goals::Families,
    "farmers"     => Scoring::Goals::Farmers,
    "fishermen"   => Scoring::Goals::Fishermen,
    "hermits"     => Scoring::Goals::Hermits,
    "knights"     => Scoring::Goals::Knights,
    "merchants"   => Scoring::Goals::Merchants,
    "miners"      => Scoring::Goals::Miners,
    "shepherds"   => Scoring::Goals::Shepherds,
    "workers"     => Scoring::Goals::Workers
  }.freeze

  def initialize(game)
    @game = game
    @game.instantiate
    @goals = Array(@game.goals).map { |k| GOAL_CLASSES.fetch(k).new(@game) }
  end

  def compute
    @game.game_players.each_with_object({}) do |gp, h|
      h[gp.order.to_s] = score_for(gp)
    end
  end

  def score_for(game_player)
    @goals.each_with_object({ "total" => 0 }) do |goal, h|
      key = GOAL_CLASSES.key(goal.class)
      result = goal.score_for(game_player)
      h[key] = result
      h["total"] += result[:score]
    end
  end
end
