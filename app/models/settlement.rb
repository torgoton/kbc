class Settlement
  attr_reader :player, :meeple_type

  def initialize(player, meeple_type: nil)
    @player = player
    @meeple_type = meeple_type
  end

  def warrior? = meeple_type == "warrior"
end
