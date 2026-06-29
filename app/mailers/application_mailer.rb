class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAIL_FROM"), # Raises if not set,
          reply_to: ENV.fetch("REPLY_TO", ENV.fetch("MAIL_FROM"))
  layout "mailer"
end
