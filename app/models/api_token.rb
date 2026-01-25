class ApiToken < ApplicationRecord
  belongs_to :user

  attr_accessor :raw_token  # Only available on creation

  before_create :generate_token

  scope :active, -> {
    where(revoked_at: nil)
      .where("expires_at IS NULL OR expires_at > ?", Time.current)
  }

  validates :name, presence: true

  def self.authenticate(token)
    return nil if token.blank?

    # Extract prefix for efficient lookup
    prefix = token[0..7]
    candidates = active.where(token_prefix: prefix)

    candidates.find { |t| BCrypt::Password.new(t.token_digest) == token }
  end

  def revoke!
    update!(revoked_at: Time.current)
  end

  def active?
    revoked_at.nil? && (expires_at.nil? || expires_at > Time.current)
  end

  private

  def generate_token
    self.raw_token = SecureRandom.urlsafe_base64(32)
    self.token_prefix = raw_token[0..7]
    self.token_digest = BCrypt::Password.create(raw_token)
  end
end
