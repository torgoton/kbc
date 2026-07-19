require "test_helper"

# Capybara's synchronize retries finders/matchers within default_max_wait_time,
# but only for errors in driver.invalid_element_errors. A Turbo Stream broadcast
# that swaps DOM nodes mid-read surfaces as a Selenium UnknownError ("Node with
# given id does not belong to the document") which isn't in that list, so it fails
# immediately instead of being retried. Treat that one error as retriable so
# post-broadcast assertions wait for the swap to settle. Message-matched rather
# than whitelisting all UnknownErrors, which would mask genuine failures.
module BroadcastRace
  STALE_NODE = "does not belong to the document"

  def self.stale_node?(error)
    error.is_a?(Selenium::WebDriver::Error::UnknownError) &&
      error.message.to_s.include?(STALE_NODE)
  end

  module RetryStaleNode
    def catch_error?(error, errors = nil)
      BroadcastRace.stale_node?(error) || super
    end
  end
end
Capybara::Node::Base.prepend(BroadcastRace::RetryStaleNode)

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # The game page is heavy (a full SVG board) and much of it re-renders via
  # Turbo broadcasts; late in the single-process suite the browser gets slow, so
  # give finders/matchers more room to retry (also widens the window the
  # stale-node retry above uses to wait out mid-broadcast DOM swaps).
  Capybara.default_max_wait_time = 5

  setup do
    # Clear the cache before each test to ensure a clean state and to work around rate limiting.
    Rails.cache.clear
    Current.reset
  end

  teardown do
    Capybara.reset_sessions!
    Current.reset
  end

  def set_field(field, value)
    page.execute_script(<<~JS, field, value)
      arguments[0].value = arguments[1];
      arguments[0].dispatchEvent(new Event("input", { bubbles: true }));
      arguments[0].dispatchEvent(new Event("change", { bubbles: true }));
    JS
  end

  def submit_form(form)
    page.execute_script("arguments[0].requestSubmit()", form)
  end

  # Reliable home-page sign-in. Uses set_field/submit_form because native
  # click_on "Sign In" intermittently fails to submit in this headless
  # container, leaving the test on the home page (a #265 flake source).
  def sign_in(email_address:, password: "password")
    visit root_path
    panel = find("#sign-in-panel")
    set_field(panel.find("input[name='email_address']"), email_address)
    set_field(panel.find("input[name='password']"), password)
    submit_form panel.find("form")
  end

  if ENV["CAPYBARA_SERVER_PORT"]
    served_by host: "rails-app", port: ENV["CAPYBARA_SERVER_PORT"]

    driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ], options: {
      browser: :remote,
      url: "http://#{ENV["SELENIUM_HOST"]}:4444"
    }
  else
    driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]
  end
end
