# frozen_string_literal: true
ActiveRecord::Schema.define do
  create_table "accounts_custom", force: :cascade do |t|
    t.string "name"
  end
end
