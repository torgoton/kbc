class Rating
  CONFIG = { start: 1500, provisional_k: 40, provisional_games: 10, stable_k: 20 }.freeze

  def initialize(game)
    @game = game
  end

  def apply!
    ActiveRecord::Base.transaction do
      return if already_rated?
      ranked = build_ranking
      deltas = compute_deltas(ranked)
      apply_deltas!(deltas)
    end
  end

  private

  def already_rated?
    @game.game_players.any? { |gp| gp.rating_after.present? }
  end

  def build_ranking
    non_resigned, resigned = @game.game_players.partition { |gp| !gp.resigned? }
    groups = non_resigned
      .group_by { |gp| @game.scores[gp.order.to_s]["total"] }
      .sort_by { |total, _| -total }
      .map(&:last)
    groups << resigned if resigned.any?
    groups
  end

  def compute_deltas(groups)
    all = groups.flatten
    rank_of = {}
    groups.each_with_index { |group, rank| group.each { |gp| rank_of[gp.id] = rank } }
    ratings = all.index_with { |gp| gp.player.rating }

    all.each_with_object({}) do |gp, deltas|
      k = k_factor_for(gp.player)
      total = all.sum do |opp|
        next 0 if opp.id == gp.id
        expected = 1.0 / (1 + 10**((ratings[opp] - ratings[gp]) / 400.0))
        actual =
          if rank_of[gp.id] < rank_of[opp.id]
            1.0
          elsif rank_of[gp.id] > rank_of[opp.id]
            0.0
          else
            0.5
          end
        actual - expected
      end
      deltas[gp.id] = (k * total).round
    end
  end

  def k_factor_for(user)
    user.rated_games_count < CONFIG[:provisional_games] ? CONFIG[:provisional_k] : CONFIG[:stable_k]
  end

  def apply_deltas!(deltas)
    game_players = @game.game_players.to_a
    users = User.where(id: game_players.map(&:user_id)).lock.index_by(&:id)
    game_players.each do |gp|
      user = users.fetch(gp.user_id)
      rating_before = user.rating
      rating_after = rating_before + deltas.fetch(gp.id)
      gp.update!(rating_before: rating_before, rating_after: rating_after)
      user.update!(rating: rating_after)
    end
  end
end
