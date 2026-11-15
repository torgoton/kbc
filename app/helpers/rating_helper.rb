module RatingHelper
  def rating_badge(user)
    provisional = user.rated_games_count < Rating::CONFIG[:provisional_games]
    "#{user.rating}#{"?" if provisional}"
  end

  def rated_list(game)
    safe_join(game.players.map { |player|
      safe_join([ "#{player.handle} (#{rating_badge(player)}) ", render("shared/presence_dot", user: player) ])
    }, ", ")
  end
end
