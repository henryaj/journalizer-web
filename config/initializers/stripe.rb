# Stripe configuration
# All keys should be set via environment variables
Stripe.api_key = ENV.fetch("STRIPE_SECRET_KEY", nil)

# Credit packages available for purchase
CREDIT_PACKAGES = {
  "10" => { pages: 10, price_cents: 100, stripe_price_id: ENV["STRIPE_PRICE_10"] },
  "50" => { pages: 50, price_cents: 450, stripe_price_id: ENV["STRIPE_PRICE_50"] },
  "100" => { pages: 100, price_cents: 800, stripe_price_id: ENV["STRIPE_PRICE_100"] }
}.freeze
