class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("SITE_EMAIL") # Raises if not set
  layout "mailer"
end
