# frozen_string_literal: true
class Account
  self.table_name = "accounts_custom"
  has_many :users
end
