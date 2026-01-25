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

  desc "Set up Stripe products and prices"
  task setup_stripe: :environment do
    require "stripe"

    Stripe.api_key = ENV.fetch("STRIPE_SECRET_KEY")

    puts "Creating Stripe product and prices..."

    # Create the product
    product = Stripe::Product.create(
      name: "Journalizer Page Credits",
      description: "Credits for transcribing handwritten journal pages"
    )
    puts "Created product: #{product.id}"

    # Create prices
    prices = [
      { credits: 10, amount: 100, nickname: "10 credits" },
      { credits: 50, amount: 450, nickname: "50 credits" },
      { credits: 100, amount: 800, nickname: "100 credits" }
    ]

    prices.each do |p|
      price = Stripe::Price.create(
        product: product.id,
        unit_amount: p[:amount],
        currency: "usd",
        nickname: p[:nickname],
        metadata: { credits: p[:credits] }
      )
      puts "Created price for #{p[:credits]} credits: #{price.id}"
      puts "  Set STRIPE_PRICE_#{p[:credits]}=#{price.id}"
    end

    puts "\nDone! Now set these environment variables on Heroku:"
    puts "  heroku config:set STRIPE_PRICE_10=<price_id_for_10>"
    puts "  heroku config:set STRIPE_PRICE_50=<price_id_for_50>"
    puts "  heroku config:set STRIPE_PRICE_100=<price_id_for_100>"
  end
end
