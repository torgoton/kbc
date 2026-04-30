class Settlement
  attr_reader :player, :meeple_type

  def initialize(player, meeple_type: nil, city_hall: false)
    @player = player
    @meeple_type = meeple_type
    @city_hall = city_hall
  end

  def warrior?   = meeple_type == "warrior"
  def ship?      = meeple_type == "ship"
  def wagon?     = meeple_type == "wagon"
  def city_hall? = @city_hall
end
