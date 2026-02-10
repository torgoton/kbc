class Action::Mandatory < Action
  def state_message
    "You must perform this action before proceeding."
  end

  def selectable_tiles
    []
  end

  def selectable?(row, col)
    false
  end
end
