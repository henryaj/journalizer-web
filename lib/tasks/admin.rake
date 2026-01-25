namespace :admin do
  desc "Add credits to a user: rake admin:add_credits[email,amount]"
  task :add_credits, [:email, :amount] => :environment do |_t, args|
    email = args[:email]
    amount = args[:amount].to_i

    user = User.find_by(email_address: email)
    if user.nil?
      puts "User not found: #{email}"
      exit 1
    end

    user.send(:add_credits!, amount, type: "bonus")
    puts "Added #{amount} credits to #{email}. New balance: #{user.reload.credit_balance}"
  end
end
