class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAIL_FROM", "kbc@mail.chrisschumann.dev")
  layout "mailer"
end
