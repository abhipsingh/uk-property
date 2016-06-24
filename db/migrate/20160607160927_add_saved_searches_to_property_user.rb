class AddSavedSearchesToPropertyUser < ActiveRecord::Migration
  def change
    add_column(:property_users, :saved_searches, :jsonb, default: '[]')
    add_column(:property_users, :shortlisted_flat_ids, :integer, array: true, default: [])
  end
end
