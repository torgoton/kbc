require "simplecov"
SimpleCov.start "rails"

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

Dir[Rails.root.join("test/support/**/*.rb")].sort.each { |f| require f }

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    parallelize_setup do |worker|
      SimpleCov.command_name "#{SimpleCov.command_name}-#{worker}"
    end

    parallelize_teardown do |worker|
      SimpleCov.result
    end

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Attach a terrain source to a BoardState and return it, so tile methods can
    # call board_contents.terrain_at without a separate board: argument. In
    # production game.instantiate does this; tests pass a BoardStub (or the real
    # Boards::Board). Idempotent.
    def with_terrain(board_contents, terrain_source)
      return board_contents if board_contents.nil?
      board_contents.terrain_source = terrain_source if terrain_source
      board_contents
    end
  end
end
