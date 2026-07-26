namespace :saas do
  desc "Re-send the admin signup notification (with approval link) for every pending account"
  task notify_pending: :environment do
    abort "Set ADMIN_EMAIL first — there is nowhere to send the notifications." if ENV["ADMIN_EMAIL"].blank?

    notified = 0
    Account.where(approved_at: nil, instance: false).find_each do |account|
      next if account.users.none? # abandoned mid-signup, nobody to approve

      Sessy::Saas::AdminMailer.new_signup(account).deliver_later
      puts "Queued notification for account ##{account.id} (#{account.name}, #{account.users.first.email_address})."
      notified += 1
    end
    puts "#{notified} pending account(s) notified."
  end
end
