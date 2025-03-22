namespace :db do
  namespace :seed do
    desc "Initial load of users during dev"
    task dev_users: :environment do
      puts "Creating users for dev"
      User.create(
        handle: "aaa",
        email_address: "a@a.aa",
        password: "aaa",
        password_confirmation: "aaa",
        approved: true
      )
      User.create(
        handle: "bbb",
        email_address: "b@b.bb",
        password: "bbb",
        password_confirmation: "bbb",
        approved: true
      )
      User.create(
        handle: "ccc",
        email_address: "c@c.cc",
        password: "ccc",
        password_confirmation: "ccc",
        approved: true
      )
    end
  end
end
