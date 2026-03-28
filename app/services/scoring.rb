class Scoring
  GOAL_CLASSES = {
    "castles"   => Scoring::Castles,
    "fishermen" => Scoring::Fishermen,
    "knights"   => Scoring::Knights,
    "merchants" => Scoring::Merchants
  }.freeze

  def initialize(game)
    @game = game
    @game.instantiate
    goal_keys = [ "castles" ] + Array(@game.goals).map(&:to_s)
    @goals = goal_keys.map { |k| GOAL_CLASSES.fetch(k).new(@game) }
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
