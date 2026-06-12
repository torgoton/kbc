# Assertions for the scenario suite. assert_undo_round_trip is the opt-in undo
# mode from the test-net plan: run an action, undo it, prove the exact
# pre-action state is restored, then replay the action and prove the
# post-action state is reproduced.
module ScenarioAssertions
  def assert_undo_round_trip(scenario)
    before = scenario.snapshot
    yield
    after = scenario.snapshot
    refute_equal before, after, "the action under test should change game state"
    scenario.undo
    assert_equal before, scenario.snapshot, "undo should restore the exact pre-action state"
    yield
    assert_equal after, scenario.snapshot, "replaying the action should reproduce the post-action state"
  end
end

class ActiveSupport::TestCase
  include ScenarioAssertions
end
