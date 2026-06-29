class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAIL_FROM") # Raises if not set
  layout "mailer"
end
