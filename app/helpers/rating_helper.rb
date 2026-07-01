module RatingHelper
  def rating_badge(user)
    provisional = user.rated_games_count < Rating::CONFIG[:provisional_games]
    "#{user.rating}#{"?" if provisional}"
  end
end
