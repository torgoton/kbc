class Action
  def state_message
    "This is the action state message."
  end

  def selectable_tiles
    tiles = []
    20.times do |row|
      20.times do |col|
        tiles << [row, col] if selectable?(row, col)
      end
    end
    tiles
  end

  def selectable?(row, col)
    false
  end

  def my_settlements(player)
    # all my settlements
  end

  def adjacent_to(player, terrain)
    # collect list of spaces
    #  - not occupied
    #  - adjacent to my settlements
    #  - of a given terrain type
  end

  def vacant_of(terrain)
    # all spaces of a given terrain type that are empty
  end
end
