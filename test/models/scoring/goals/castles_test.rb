require_relative "goal_test_case"

class Scoring::Goals::CastlesTest < Scoring::Goals::GoalTestCase
  # Board layout: [Oasis(0), Paddock(0), Farm(0), Tavern(0)]
  #
  # Castle positions (global) from scoring_hexes:
  #   OasisBoard   i=0: local (7,1)  → global (7,1)   terrain=S
  #   PaddockBoard i=1: local (7,5)  → global (7,15)  terrain=S
  #   FarmBoard    i=2: local (1,1)  → global (11,1)  terrain=S
  #   TavernBoard  i=3: local (3,3)  → global (13,13) terrain=S
  #
  # Neighbors of castle (7,1) [odd row]: (7,0),(7,2),(6,1),(6,2),(8,1),(8,2)
  # Neighbors of castle (7,15)[odd row]: (7,14),(7,16),(6,15),(6,16),(8,15),(8,16)

  test "0 when no settlement is adjacent to a castle hex" do
    ctx = build_game(chris_settlements: [ [ 0, 0 ] ])
    result = Scoring::Goals::Castles.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 0, result[:score]
  end

  test "3 for one castle with an adjacent settlement" do
    # (6,1) is adjacent to castle (7,1)
    ctx = build_game(chris_settlements: [ [ 6, 1 ] ])
    result = Scoring::Goals::Castles.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 3, result[:score]
  end

  test "castle counted once even with multiple adjacent settlements" do
    ctx = build_game(chris_settlements: [ [ 6, 1 ], [ 6, 2 ] ])
    result = Scoring::Goals::Castles.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 3, result[:score]
  end

  test "3 per castle hex with at least one adjacent settlement" do
    # (6,1) adjacent to castle (7,1); (6,15) adjacent to castle (7,15)
    ctx = build_game(chris_settlements: [ [ 6, 1 ], [ 6, 15 ] ])
    result = Scoring::Goals::Castles.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 6, result[:score]
  end
end
