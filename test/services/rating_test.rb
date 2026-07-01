require "test_helper"

class RatingTest < ActiveSupport::TestCase
  test "higher-rated winner gains a small amount, loser loses the same amount" do
    game = games(:game2player)
    chris = game_players(:chris)
    paula = game_players(:paula)
    users(:chris).update!(rating: 1600)
    users(:paula).update!(rating: 1400)
    game.update!(scores: { "0" => { "total" => 10 }, "1" => { "total" => 5 } })

    Rating.new(game).apply!

    assert_equal 1610, users(:chris).reload.rating
    assert_equal 1390, users(:paula).reload.rating
  end

  test "upset win by the lower-rated player is a big swing" do
    game = games(:game2player)
    chris = game_players(:chris)
    paula = game_players(:paula)
    users(:chris).update!(rating: 1600)
    users(:paula).update!(rating: 1400)
    game.update!(scores: { "0" => { "total" => 5 }, "1" => { "total" => 10 } })

    Rating.new(game).apply!

    assert_equal 1570, users(:chris).reload.rating
    assert_equal 1430, users(:paula).reload.rating
  end

  test "a draw converges ratings toward each other" do
    game = games(:game2player)
    chris = game_players(:chris)
    paula = game_players(:paula)
    users(:chris).update!(rating: 1600)
    users(:paula).update!(rating: 1400)
    game.update!(scores: { "0" => { "total" => 10 }, "1" => { "total" => 10 } })

    Rating.new(game).apply!

    assert_equal 1590, users(:chris).reload.rating
    assert_equal 1410, users(:paula).reload.rating
  end

  test "a resigned player ranks as a loss regardless of their board total" do
    game = games(:game2player)
    chris = game_players(:chris)
    paula = game_players(:paula)
    chris.update!(resigned_at: Time.current)
    game.update!(scores: { "0" => { "total" => 100 }, "1" => { "total" => 1 } })

    Rating.new(game).apply!

    assert_equal 1480, users(:chris).reload.rating
    assert_equal 1520, users(:paula).reload.rating
  end

  test "N-player: a mid-rank finish nets between beating everyone and losing to everyone" do
    game = Game.create!(state: "completed")
    first = GamePlayer.create!(game: game, player: users(:chris), order: 0)
    second = GamePlayer.create!(game: game, player: users(:paula), order: 1)
    third = GamePlayer.create!(game: game, player: users(:jules), order: 2)
    game.update!(scores: {
      "0" => { "total" => 30 },
      "1" => { "total" => 20 },
      "2" => { "total" => 10 }
    })

    Rating.new(game).apply!

    assert_equal 1540, users(:chris).reload.rating
    assert_equal 1500, users(:paula).reload.rating
    assert_equal 1460, users(:jules).reload.rating
  end

  test "applying twice does not double-rate the game" do
    game = games(:game2player)
    game.update!(scores: { "0" => { "total" => 10 }, "1" => { "total" => 5 } })

    Rating.new(game).apply!
    chris_rating_after_first = users(:chris).reload.rating
    Rating.new(game).apply!

    assert_equal chris_rating_after_first, users(:chris).reload.rating
  end

  test "writes rating_before/rating_after snapshots and syncs users.rating" do
    game = games(:game2player)
    chris = game_players(:chris)
    game.update!(scores: { "0" => { "total" => 10 }, "1" => { "total" => 5 } })

    Rating.new(game).apply!
    chris.reload

    assert_equal 1500, chris.rating_before
    assert_equal chris.rating_after, users(:chris).reload.rating
  end

  test "K-factor drops from 40 to 20 once a player has 10 rated games" do
    veteran = users(:jules)
    10.times do |n|
      filler = Game.create!(state: "completed")
      GamePlayer.create!(game: filler, player: veteran, order: 0, rating_after: 1500)
      GamePlayer.create!(game: filler, player: users(:paula), order: 1, rating_after: 1500)
    end
    assert_equal 10, veteran.rated_games_count

    game = games(:game2player)
    chris = game_players(:chris)
    game.game_players.destroy(game_players(:paula))
    veteran_gp = GamePlayer.create!(game: game, player: veteran, order: 1)
    game.update!(scores: { "0" => { "total" => 10 }, "1" => { "total" => 5 } })

    Rating.new(game).apply!

    # equal ratings (1500 vs 1500), chris (provisional, K=40) wins: +20
    # veteran (stable, K=20) loses: -10
    assert_equal 1520, users(:chris).reload.rating
    assert_equal 1490, veteran.reload.rating
  end
end
