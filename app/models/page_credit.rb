class PageCredit < ApplicationRecord
  belongs_to :user
  belongs_to :transcription_job, optional: true

  validates :transaction_type, presence: true,
                               inclusion: { in: %w[purchase usage refund bonus] }
  validates :amount, presence: true
  validates :balance_after, presence: true

  scope :purchases, -> { where(transaction_type: "purchase") }
  scope :usage, -> { where(transaction_type: "usage") }
end
