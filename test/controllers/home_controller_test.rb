require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get home_index_url
    assert_response :success
  end

  test "sign-in password field allows passwords as long as sign-up allows" do
    get home_index_url
    doc = Nokogiri::HTML(response.body)
    signup_maxlength = doc.at_css("#sign-up-panel input[name='user[password]']")["maxlength"]
    signin_maxlength = doc.at_css("#sign-in-panel input[name='password']")["maxlength"]
    assert_equal signup_maxlength, signin_maxlength
    assert_equal ActiveModel::SecurePassword::MAX_PASSWORD_LENGTH_ALLOWED.to_s, signin_maxlength
  end
end
