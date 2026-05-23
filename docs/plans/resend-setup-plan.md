• Resend Setup Plan

  1. Create the Resend account

  Go to https://resend.com and create an account. Once you are in the dashboard, do not use a personal sender address for production. Use your domain.

  2. Add the sending domain

  In Resend, add:

  chrisschumann.dev

  You want to send from:

  kbc@chrisschumann.dev

  Resend will give you DNS records to add, usually including DKIM and SPF-related records. Add those records wherever chrisschumann.dev DNS is managed.

  3. Wait for domain verification

  After adding DNS records, return to Resend and wait until the domain shows as verified. DNS can take a few minutes, sometimes longer.

  Do not wire Rails to production until Resend says the domain is verified, otherwise password reset emails may fail or land in spam.

  4. Create an SMTP credential or API key

  For simplest Rails setup, use SMTP.

  In Resend, create SMTP credentials. You should end up with values like:

  SMTP_ADDRESS=smtp.resend.com
  SMTP_PORT=587
  SMTP_USERNAME=resend
  SMTP_PASSWORD=<your_resend_smtp_password_or_api_key>
  SMTP_DOMAIN=chrisschumann.dev
  MAIL_FROM=kbc@chrisschumann.dev
  APP_HOST=kbc.chrisschumann.dev

  Resend may present the password as an API key. Treat it as a secret.

  5. Add Rails production mail config

  Update production config to read mail settings from env vars:

  config.action_mailer.raise_delivery_errors = true

  config.action_mailer.default_url_options = {
    host: ENV.fetch("APP_HOST")
  }

  config.action_mailer.smtp_settings = {
    address: ENV.fetch("SMTP_ADDRESS"),
    port: ENV.fetch("SMTP_PORT", 587).to_i,
    domain: ENV.fetch("SMTP_DOMAIN"),
    user_name: ENV.fetch("SMTP_USERNAME"),
    password: ENV.fetch("SMTP_PASSWORD"),
    authentication: :plain,
    enable_starttls_auto: true
  }

  Also update ApplicationMailer:

  default from: ENV.fetch("MAIL_FROM", "kbc@chrisschumann.dev")

  6. Add Kamal secrets/env vars

  In config/deploy.yml, add the sensitive values under env.secret:

  env:
    secret:
      - RAILS_MASTER_KEY
      - DATABASE_URL
      - SMTP_PASSWORD

  Add non-secret config under env.clear:

  env:
    clear:
      APP_HOST: kbc.chrisschumann.dev
      MAIL_FROM: kbc@chrisschumann.dev
      SMTP_ADDRESS: smtp.resend.com
      SMTP_PORT: 587
      SMTP_USERNAME: resend
      SMTP_DOMAIN: chrisschumann.dev

  Then add SMTP_PASSWORD to .kamal/secrets in whatever pattern you are already using.

  7. Deploy

  Run:

  bin/kamal deploy

  Then watch logs:

  bin/kamal logs

  8. Test the real flow

  In production:

  1. Go to the sign-in page.
  2. Click “Forgot password?”
  3. Enter your real email address.
  4. Submit.
  5. Check Resend logs for the outgoing message.
  6. Confirm the email arrives.
  7. Click the reset link.
  8. Set a new password.
  9. Sign in with the new password.
  10. Check DNS health

  After the first successful send, verify:

  - Resend shows the email as delivered.
  - SPF/DKIM pass in the received email headers.
  - The email does not land in spam.
  - The reset link uses https://kbc.chrisschumann.dev, not example.com.

  10. Add a DMARC record if missing

  If chrisschumann.dev does not already have DMARC, add a starter policy:

  Name: _dmarc
  Type: TXT
  Value: v=DMARC1; p=none; rua=mailto:kbc@chrisschumann.dev

  Later, once delivery is stable, you can tighten p=none to quarantine or reject.
