module AdminAuthorization
  extend ActiveSupport::Concern

  included do
    before_action :require_admin
  end

  private

  def admin_emails
    ENV.fetch("ADMIN_EMAILS", "").split(",").map(&:strip).map(&:downcase)
  end

  def require_admin
    unless admin_user?
      flash[:alert] = "You don't have permission to access this page."
      redirect_to root_path
    end
  end

  def admin_user?
    Current.user.present? && admin_emails.include?(Current.user.email_address.downcase)
  end
end
