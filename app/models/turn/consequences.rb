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
              when "tile_discarded" then TileDiscarded
              when "build_recorded" then BuildRecorded
              when "outpost_activated" then OutpostActivated
              when "outpost_deactivated" then OutpostDeactivated
              when "irreversible_boundary" then IrreversibleBoundary
              when "card_drawn" then CardDrawn
              when "sub_phase_state_updated" then SubPhaseStateUpdated
              when "hand_refreshed" then HandRefreshed
              when "current_player_advanced" then CurrentPlayerAdvanced
              when "turn_reset" then TurnReset
              when "end_triggered" then EndTriggered
              when "game_completed" then GameCompleted
              when "tiles_reset" then TilesReset
              when "nomad_tiles_expired" then NomadTilesExpired
              else raise ArgumentError, "unknown consequence type: #{hash["type"].inspect}"
              end
      klass.from_h(hash)
    end
  end
end
