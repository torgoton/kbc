class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_url, alert: "Try again later." }

  def new
    session[:return_to_after_authenticating] = dashboard_path
  end

  def create
    if user = User.authenticate_by(params.permit(:email_address, :password))
      if !user.approved
        redirect_to unapproved_users_url
      else
        start_new_session_for user
        redirect_to after_authentication_url
      end
    else
      redirect_to new_session_path, alert: "Try another email address or password."
    end
  end

  def destroy
    terminate_session
    redirect_to root_path
  end
end
