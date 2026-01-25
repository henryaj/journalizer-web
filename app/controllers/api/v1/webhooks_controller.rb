module Api
  module V1
    class WebhooksController < ActionController::API
      # No authentication for webhooks - Stripe signature verification instead

      def stripe
        payload = request.body.read
        sig_header = request.env["HTTP_STRIPE_SIGNATURE"]

        begin
          event = Stripe::Webhook.construct_event(
            payload, sig_header, ENV.fetch("STRIPE_WEBHOOK_SECRET", "")
          )
        rescue JSON::ParserError
          return head :bad_request
        rescue Stripe::SignatureVerificationError
          return head :bad_request
        end

        case event.type
        when "checkout.session.completed"
          handle_checkout_completed(event.data.object)
        when "payment_intent.payment_failed"
          handle_payment_failed(event.data.object)
        end

        head :ok
      end

      private

      def handle_checkout_completed(session)
        user_id = session.metadata["user_id"]
        pages = session.metadata["pages"].to_i

        user = User.find(user_id)
        user.add_credits!(
          pages,
          stripe_payment_intent_id: session.payment_intent,
          type: "purchase"
        )

        Rails.logger.info "Added #{pages} credits to user #{user.id}"
      rescue ActiveRecord::RecordNotFound => e
        Rails.logger.error "Stripe webhook: User not found: #{e.message}"
      end

      def handle_payment_failed(payment_intent)
        Rails.logger.warn "Payment failed: #{payment_intent.id}"
        # Could notify user via email here
      end
    end
  end
end
