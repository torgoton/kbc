class AdminMailer < ApplicationMailer
  def new_signup(user)
    @user = user
    mail subject: "New signup: #{user.handle}", to: ENV.fetch("ADMIN_EMAIL")
  end
end
