# frozen_string_literal: true
ActiveRecord::Schema.define do
  create_table "users", force: :cascade do |t|
    t.string "name"
    t.integer "account_id"
  end
  create_table "orders", force: :cascade do |t|
    t.integer "user_id"
  end
end
