module RatingHelper
  def rating_badge(user)
    provisional = user.rated_games_count < Rating::CONFIG[:provisional_games]
    "#{user.rating}#{"?" if provisional}"
  end

  def rated_list(game)
    game.players.map { |player| "#{player.handle} (#{rating_badge(player)})" }.join(", ")
  end
end
