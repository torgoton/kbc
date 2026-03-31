class Scoring
  GOAL_CLASSES = {
    "castles"     => Scoring::Goals::Castles,
    "citizens"    => Scoring::Goals::Citizens,
    "discoverers" => Scoring::Goals::Discoverers,
    "farmers"     => Scoring::Goals::Farmers,
    "fishermen"   => Scoring::Goals::Fishermen,
    "hermits"     => Scoring::Goals::Hermits,
    "knights"     => Scoring::Goals::Knights,
    "merchants"   => Scoring::Goals::Merchants,
    "miners"      => Scoring::Goals::Miners,
    "workers"     => Scoring::Goals::Workers
  }.freeze

  GOAL_DESCRIPTIONS = {
    "castles"     => "3 points for each Castle you have a piece adjacent to",
    "citizens"    => "1 point for every 2 pieces in your largest group",
    "discoverers" => "1 point for each horizontal line on which you have at least 1 piece",
    "farmers"     => "3 points for each of your pieces on the board section with the fewest such pieces",
    "fishermen"   => "1 point for each piece next to but not on water",
    "hermits"     => "1 point for each of your settlement areas",
    "knights"     => "2 points for each piece on the line with the most pieces",
    "merchants"   => "4 points for each location connected to any other location with your pieces",
    "miners"      => "1 point for each piece next to but not on a mountain space",
    "workers"     => "1 point for each piece next to a castle or location space"
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
