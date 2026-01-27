class Session < ApplicationRecord
  belongs_to :user

  encrypts :ip_address
end
