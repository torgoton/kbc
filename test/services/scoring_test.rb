require "test_helper"

class ScoringTest < ActiveSupport::TestCase
  # Board layout throughout: [Oasis(0), Paddock(0), Farm(0), Tavern(0)]
  #
  # Castle positions (global) from scoring_hexes:
  #   OasisBoard   i=0: local (7,1)  → global (7,1)   terrain=S
  #   PaddockBoard i=1: local (7,5)  → global (7,15)  terrain=S
  #   FarmBoard    i=2: local (1,1)  → global (11,1)  terrain=S
  #   TavernBoard  i=3: local (3,3)  → global (13,13) terrain=S
  #
  # "L" terrain hexes (global, sample):
  #   OasisBoard: (2,7), (7,5)
  #
  # OasisBoard row 7: "WSCFWLDDCW"
  #   (7,1)=S(castle), (7,2)=C, (7,3)=F, (7,4)=W, (7,5)=L
  #
  # Neighbors of castle (7,1) [odd row]: (7,0),(7,2),(6,1),(6,2),(8,1),(8,2)
  # Neighbors of castle (7,15)[odd row]: (7,14),(7,16),(6,15),(6,16),(8,15),(8,16)

  BOARDS = [ [ "Oasis", 0 ], [ "Paddock", 0 ], [ "Farm", 0 ], [ "Tavern", 0 ] ]

  def build_game(chris_settlements: [], paula_settlements: [], goals: [])
    game = games(:game2player)
    chris = game_players(:chris)
    paula = game_players(:paula)
    game.boards = BOARDS
    game.goals  = goals
    game.board_contents = BoardState.new.tap do |s|
      chris_settlements.each { |r, c| s.place_settlement(r, c, chris.order) }
      paula_settlements.each { |r, c| s.place_settlement(r, c, paula.order) }
    end
    game.save
    game.instantiate
    { game: game, chris: chris, paula: paula }
  end

  # ── Castles ─────────────────────────────────────────────────────────────────

  test "Castles: 0 when no settlement is adjacent to a castle hex" do
    ctx = build_game(chris_settlements: [ [ 0, 0 ] ])
    result = Scoring::Castles.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 0, result[:score]
  end

  test "Castles: 3 for one castle with an adjacent settlement" do
    # (6,1) is adjacent to castle (7,1)
    ctx = build_game(chris_settlements: [ [ 6, 1 ] ])
    result = Scoring::Castles.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 3, result[:score]
  end

  test "Castles: castle counted once even with multiple adjacent settlements" do
    ctx = build_game(chris_settlements: [ [ 6, 1 ], [ 6, 2 ] ])
    result = Scoring::Castles.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 3, result[:score]
  end

  test "Castles: 3 per castle hex with at least one adjacent settlement" do
    # (6,1) adjacent to castle (7,1); (6,15) adjacent to castle (7,15)
    ctx = build_game(chris_settlements: [ [ 6, 1 ], [ 6, 15 ] ])
    result = Scoring::Castles.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 6, result[:score]
  end

  # ── Fishermen ────────────────────────────────────────────────────────────────

  test "Fishermen: 0 when no settlement is adjacent to water" do
    # (0,7)=G on OasisBoard; even-row neighbors (0,6)=T,(0,8)=G,(1,6)=T,(1,7)=T — no W
    ctx = build_game(chris_settlements: [ [ 0, 7 ] ])
    result = Scoring::Fishermen.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 0, result[:score]
  end

  test "Fishermen: 1 for a non-water settlement adjacent to water" do
    # OasisBoard row 3: "WWWFGTFFFF" — (3,3)=F; odd-row neighbor (3,2)=W
    ctx = build_game(chris_settlements: [ [ 3, 3 ] ])
    result = Scoring::Fishermen.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 1, result[:score]
  end

  test "Fishermen: 0 for a settlement on water terrain" do
    # (3,0)=W on OasisBoard — on water, so does not score
    ctx = build_game(chris_settlements: [ [ 3, 0 ] ])
    result = Scoring::Fishermen.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 0, result[:score]
  end

  test "Fishermen: counts all qualifying settlements" do
    # (3,3)=F adj to (3,2)=W; (8,3)=F adj to (8,2)=W and (8,4)=W
    # OasisBoard row 8: "WWCFWWWDDW" — (8,3)=F
    ctx = build_game(chris_settlements: [ [ 3, 3 ], [ 8, 3 ] ])
    result = Scoring::Fishermen.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 2, result[:score]
  end

  # ── Knights ──────────────────────────────────────────────────────────────────

  test "Knights: 0 with no settlements" do
    ctx = build_game
    result = Scoring::Knights.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 0, result[:score]
  end

  test "Knights: 2× the count on the single best row" do
    # 3 settlements on row 5 → score = 6
    ctx = build_game(chris_settlements: [ [ 5, 0 ], [ 5, 2 ], [ 5, 4 ] ])
    result = Scoring::Knights.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 6, result[:score]
  end

  test "Knights: scores only one row when rows are tied" do
    # 2 on row 5 and 2 on row 8 → score = 4, not 8
    ctx = build_game(chris_settlements: [ [ 5, 0 ], [ 5, 2 ], [ 8, 3 ], [ 8, 7 ] ])
    result = Scoring::Knights.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 4, result[:score]
  end

  # ── Merchants ────────────────────────────────────────────────────────────────

  test "Merchants: 0 when component touches fewer than 2 special hexes" do
    # (7,2) is adjacent only to castle (7,1)
    ctx = build_game(chris_settlements: [ [ 7, 2 ] ])
    result = Scoring::Merchants.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 0, result[:score]
  end

  test "Merchants: 4 per special hex when component touches 2 or more" do
    # Chain (7,2)-(7,3)-(7,4): adj to castle (7,1) and L-terrain (7,5) → 4×2 = 8
    ctx = build_game(chris_settlements: [ [ 7, 2 ], [ 7, 3 ], [ 7, 4 ] ])
    result = Scoring::Merchants.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 8, result[:score]
  end

  test "Merchants: isolated component with no special hexes scores 0" do
    ctx = build_game(chris_settlements: [ [ 0, 0 ], [ 7, 2 ], [ 7, 3 ], [ 7, 4 ] ])
    result = Scoring::Merchants.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 8, result[:score]
  end

  # ── Scoring coordinator ──────────────────────────────────────────────────────

  test "score_for returns hash with per-goal results and a total" do
    # (6,2)=C adj to castle (7,1); even-row neighbors: (6,1)=T,(6,3)=T,(5,1)=T,(5,2)=T,(7,1)=S,(7,2)=C — no W
    # castles=3, fishermen=0, knights=2 (1 settlement on row 6), merchants=0, total=5
    ctx = build_game(
      chris_settlements: [ [ 6, 2 ] ],
      goals: [ "fishermen", "knights", "merchants" ]
    )
    result = Scoring.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 3, result["castles"][:score]
    assert_equal 0, result["fishermen"][:score]
    assert_equal 2, result["knights"][:score]
    assert_equal 0, result["merchants"][:score]
    assert_equal 5, result["total"]
  end

  test "castles goal is always included regardless of game.goals" do
    ctx = build_game(chris_settlements: [ [ 6, 2 ] ], goals: [])
    result = Scoring.new(ctx[:game]).score_for(ctx[:chris])
    assert result.key?("castles"), "castles must always be present"
    assert_equal 3, result["castles"][:score]
  end

  test "compute returns a hash keyed by player order string covering all players" do
    ctx = build_game(
      chris_settlements: [ [ 6, 2 ] ],
      goals: [ "fishermen", "knights", "merchants" ]
    )
    result = Scoring.new(ctx[:game]).compute
    assert result.key?(ctx[:chris].order.to_s)
    assert result.key?(ctx[:paula].order.to_s)
    assert_equal 5, result[ctx[:chris].order.to_s]["total"]
    assert_equal 0, result[ctx[:paula].order.to_s]["total"]
  end
end
