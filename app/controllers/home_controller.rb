class HomeController < ApplicationController
  allow_unauthenticated_access

  def index
    return redirect_to dashboard_path if authenticated?

    session[:return_to_after_authenticating] = dashboard_path
    @user = User.new
  end
end
