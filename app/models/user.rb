class User < ApplicationRecord
  has_secure_password validations: false  # We handle password validation manually
  has_many :sessions, dependent: :destroy
  has_many :api_tokens, dependent: :destroy
  has_many :page_credits, dependent: :destroy
  has_many :transcription_jobs, dependent: :destroy
  has_many :journal_entries, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true,
                            format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, presence: true, length: { minimum: 8 }, if: :password_required?

  class InsufficientCreditsError < StandardError; end

  # Find or create user from OAuth data
  def self.from_omniauth(auth)
    where(provider: auth.provider, uid: auth.uid).first_or_create do |user|
      user.email_address = auth.info.email
      user.name = auth.info.name
      user.avatar_url = auth.info.image
      # No password for OAuth users
    end
  end

  def oauth_user?
    provider.present?
  end

  def display_name
    name.presence || email_address.split("@").first
  end

  private

  def password_required?
    !oauth_user? && (new_record? || password.present?)
  end

  def has_credits?(amount = 1)
    credit_balance >= amount
  end

  def deduct_credits!(amount, job:)
    transaction do
      raise InsufficientCreditsError, "Insufficient credits" unless has_credits?(amount)

      new_balance = credit_balance - amount
      update!(credit_balance: new_balance)

      page_credits.create!(
        transaction_type: "usage",
        amount: -amount,
        balance_after: new_balance,
        transcription_job: job
      )
    end
  end

  def add_credits!(amount, stripe_payment_intent_id: nil, type: "purchase")
    transaction do
      new_balance = credit_balance + amount
      update!(credit_balance: new_balance)

      page_credits.create!(
        transaction_type: type,
        amount: amount,
        balance_after: new_balance,
        stripe_payment_intent_id: stripe_payment_intent_id
      )
    end
  end
end
