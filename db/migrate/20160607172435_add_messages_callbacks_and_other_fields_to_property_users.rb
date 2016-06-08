class AddMessagesCallbacksAndOtherFieldsToPropertyUsers < ActiveRecord::Migration
  def change
    add_column(:property_users, :messages, :jsonb, default: '[]')
    add_column(:property_users, :callbacks, :jsonb, default: '[]')
    add_column(:property_users, :viewings, :jsonb, default: '[]')
    add_column(:property_users, :offers, :jsonb, default: '[]')
  end
end
