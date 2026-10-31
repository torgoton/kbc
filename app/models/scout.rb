# A Scout Cabin token on the board: counts as its player's piece for adjacency only.
class Scout
  attr_reader :player

  def initialize(player)
    @player = player
  end
end
