# frozen_string_literal: true
class User
  belongs_to :account
  has_many :orders
end
