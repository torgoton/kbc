require "application_system_test_case"

# Unit-level check for the stale-node predicate that makes post-broadcast
# assertions retriable (see application_system_test_case.rb). No browser needed.
class BroadcastRaceTest < ApplicationSystemTestCase
  test "stale_node? matches the Turbo broadcast race error, nothing else" do
    stale = Selenium::WebDriver::Error::UnknownError.new(
      "Node with given id does not belong to the document"
    )
    assert BroadcastRace.stale_node?(stale)

    other_unknown = Selenium::WebDriver::Error::UnknownError.new("some other failure")
    assert_not BroadcastRace.stale_node?(other_unknown)

    assert_not BroadcastRace.stale_node?(RuntimeError.new("does not belong to the document"))
  end
end
