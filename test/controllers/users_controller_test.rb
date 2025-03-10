require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  # test "should not get index" do
  #   get users_url
  #   assert_redirected_to new_session_path
  # end

  test "should get new" do
    get new_user_url
    assert_response :success
  end

  test "should create a new user" do
    assert_difference("User.count", 1) do
      post users_url, params: { user: {
        handle: "Barney",
        email_address: "brubble@example.com",
        password: "abc123"
      } }
    end

    # assert_response :unprocessable_entity
    assert_redirected_to unapproved_users_path
  end

  test "should not show user" do
    get user_url(@user)
    assert_redirected_to new_session_path
  end

  # test "should not get edit" do
  #   get edit_user_url(@user)
  #   assert_redirected_to new_session_path
  # end

  # test "should not update user" do
  #   patch user_url(@user), params: { user: {} }
  #   assert_redirected_to new_session_path
  #   # assert_redirected_to user_url(@user)
  # end

  # test "should not destroy user" do
  #   assert_difference("User.count", 0) do
  #     delete user_url(@user)
  #   end

  #   assert_redirected_to new_session_path
  #   # assert_redirected_to users_url
  # end
end
