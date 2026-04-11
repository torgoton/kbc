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

  # ── Scoring coordinator ──────────────────────────────────────────────────────

  test "score_for returns hash with per-goal results and a total" do
    # (6,2)=C adj to castle (7,1); even-row neighbors: (6,1)=T,(6,3)=T,(5,1)=T,(5,2)=T,(7,1)=S,(7,2)=C — no W
    # castles=3, fishermen=0, knights=2 (1 settlement on row 6), merchants=0, total=5
    ctx = build_game(
      chris_settlements: [ [ 6, 2 ] ],
      goals: [ "castles", "fishermen", "knights", "merchants" ]
    )
    result = Scoring.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 3, result["castles"][:score]
    assert_equal 0, result["fishermen"][:score]
    assert_equal 2, result["knights"][:score]
    assert_equal 0, result["merchants"][:score]
    assert_equal 5, result["total"]
  end

  test "castles goal is only scored when present in game.goals" do
    ctx = build_game(chris_settlements: [ [ 6, 2 ] ], goals: [])
    result = Scoring.new(ctx[:game]).score_for(ctx[:chris])
    assert_not result.key?("castles"), "castles must not be present when not in goals"
    assert_equal 0, result["total"]
  end

  test "bonus_scores not covered by a goal are included in score_for total" do
    ctx = build_game(chris_settlements: [], goals: [])
    ctx[:chris].update!(bonus_scores: { "treasure" => 3 })
    result = Scoring.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 3, result["treasure"][:score]
    assert_equal 3, result["total"]
  end

  test "compute returns a hash keyed by player order string covering all players" do
    ctx = build_game(
      chris_settlements: [ [ 6, 2 ] ],
      goals: [ "castles", "fishermen", "knights", "merchants" ]
    )
    result = Scoring.new(ctx[:game]).compute
    assert result.key?(ctx[:chris].order.to_s)
    assert result.key?(ctx[:paula].order.to_s)
    assert_equal 5, result[ctx[:chris].order.to_s]["total"]
    assert_equal 0, result[ctx[:paula].order.to_s]["total"]
  end
end
