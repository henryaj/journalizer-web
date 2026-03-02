# Create a dev user for local development
if Rails.env.development?
  dev_user = User.find_or_initialize_by(email_address: "dev@example.com")

  if dev_user.new_record?
    dev_user.name = "Dev User"
    dev_user.password = "password123"
    dev_user.save!
    # Set credits directly to avoid callback validation issues
    credits = ENV["LOCAL_MODE"].present? ? 999_999 : 100
    dev_user.update_column(:credit_balance, credits)
    puts "Created dev user: dev@example.com / password123 (#{credits} credits)"
  else
    puts "Dev user already exists: dev@example.com (#{dev_user.credit_balance} credits)"
  end
end
