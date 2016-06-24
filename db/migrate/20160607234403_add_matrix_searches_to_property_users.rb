class AddMatrixSearchesToPropertyUsers < ActiveRecord::Migration
  def change
    add_column(:property_users, :matrix_searches, :jsonb, default: '[]')
  end
end
