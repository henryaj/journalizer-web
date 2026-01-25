class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :api_tokens, dependent: :destroy
  has_many :page_credits, dependent: :destroy
  has_many :transcription_jobs, dependent: :destroy
  has_many :journal_entries, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true,
                            format: { with: URI::MailTo::EMAIL_REGEXP }

  class InsufficientCreditsError < StandardError; end

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
