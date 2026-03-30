class GameReplayer
  def initialize(game)
    @state = MoveApplicator::HashState.new(game.base_snapshot)
    @moves = game.moves
  end

  def replay
    @moves.order(:order).each { |move| MoveApplicator.dispatch(@state, move) }
    @state.result
  end
end
