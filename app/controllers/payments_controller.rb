class PaymentsController < ApplicationController
  before_action :require_authentication

  def new
    @packages = CREDIT_PACKAGES
    @credit_balance = Current.user.credit_balance
  end

  def create
    package = CREDIT_PACKAGES[params[:package]]
    raise ActionController::BadRequest, "Invalid package" unless package
    raise ActionController::BadRequest, "Stripe not configured" unless package[:stripe_price_id].present?

    # Ensure user has Stripe customer ID
    ensure_stripe_customer!

    session = Stripe::Checkout::Session.create(
      customer: Current.user.stripe_customer_id,
      payment_method_types: ["card"],
      line_items: [{
        price: package[:stripe_price_id],
        quantity: 1
      }],
      mode: "payment",
      success_url: payments_success_url + "?session_id={CHECKOUT_SESSION_ID}",
      cancel_url: payments_cancel_url,
      metadata: {
        user_id: Current.user.id,
        pages: package[:pages]
      }
    )

    redirect_to session.url, allow_other_host: true
  end

  def success
    @credits = Current.user.credit_balance
    # Credits are added via webhook, so they might not be reflected immediately
    # The view should explain this
  end

  def cancel
    redirect_to new_payment_path, notice: "Payment cancelled."
  end

  private

  def ensure_stripe_customer!
    return if Current.user.stripe_customer_id.present?

    customer = Stripe::Customer.create(
      email: Current.user.email_address,
      metadata: { user_id: Current.user.id }
    )

    Current.user.update!(stripe_customer_id: customer.id)
  end
end
