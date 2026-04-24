class Settlement
  attr_reader :player, :meeple_type

  def initialize(player, meeple_type: nil)
    @player = player
    @meeple_type = meeple_type
  end

  def warrior? = meeple_type == "warrior"
  def ship?    = meeple_type == "ship"
  def wagon?   = meeple_type == "wagon"
end
