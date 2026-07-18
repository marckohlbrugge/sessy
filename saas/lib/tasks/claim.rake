namespace :saas do
  desc "Attach an owner to the instance account for the hosted launch (idempotent). Usage: rake saas:claim[you@example.com]"
  task :claim, [ :email ] => :environment do |_task, args|
    email = args[:email]
    abort "Usage: bin/rails saas:claim[you@example.com]" if email.blank?

    account = Sessy::Saas::Claim.run(email)
    puts "Claimed account ##{account.id} (#{account.sources.count} sources) as #{email}."
  end
end
