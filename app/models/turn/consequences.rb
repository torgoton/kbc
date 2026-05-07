class Turn
  module Consequences
    def self.from_h(hash)
      klass = case hash["type"]
              when "error" then Error
              when "settlement_placed" then SettlementPlaced
              when "tile_consumed" then TileConsumed
              when "tile_picked_up" then TilePickedUp
              when "sub_phase_pushed" then SubPhasePushed
              when "sub_phase_popped" then SubPhasePopped
              when "mandatory_remaining_decremented" then MandatoryRemainingDecremented
              when "meeple_granted" then MeepleGranted
              when "goal_scored" then GoalScored
              else raise ArgumentError, "unknown consequence type: #{hash["type"].inspect}"
              end
      klass.from_h(hash)
    end
  end
end
