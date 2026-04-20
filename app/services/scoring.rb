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

  TASK_CLASSES = {
    "advance"        => Scoring::Tasks::Advance,
    "compass_points" => Scoring::Tasks::CompassPoints,
    "fortress"       => Scoring::Tasks::Fortress,
    "home_country"   => Scoring::Tasks::HomeCountry,
    "place_of_refuge" => Scoring::Tasks::PlaceOfRefuge,
    "road"           => Scoring::Tasks::Road
  }.freeze

  SCORER_CLASSES = GOAL_CLASSES.merge(TASK_CLASSES).freeze

  def initialize(game)
    @game = game
    @game.instantiate
    @scorers = Array(@game.goals).map { |k| SCORER_CLASSES.fetch(k).new(@game) }
  end

  def compute
    @game.game_players.each_with_object({}) do |gp, h|
      h[gp.order.to_s] = score_for(gp)
    end
  end

  def score_for(game_player)
    scorer_keys = @scorers.map { |s| SCORER_CLASSES.key(s.class) }.to_set
    h = @scorers.each_with_object({ "total" => 0 }) do |scorer, acc|
      key = SCORER_CLASSES.key(scorer.class)
      result = scorer.score_for(game_player)
      acc[key] = result
      acc["total"] += result[:score]
    end
    (game_player.bonus_scores || {}).each do |key, score|
      next if scorer_keys.include?(key)
      h[key] = { score: score }
      h["total"] += score
    end
    h
  end
end
