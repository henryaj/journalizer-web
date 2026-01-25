module Api
  module V1
    class UsersController < BaseController
      # GET /api/v1/me
      def me
        render json: {
          user: {
            id: current_user.id,
            email: current_user.email_address,
            credit_balance: current_user.credit_balance,
            entries_count: current_user.journal_entries.not_expired.count
          }
        }
      end
    end
  end
end
