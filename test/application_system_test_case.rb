require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
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
