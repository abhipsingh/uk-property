class AddUniqueIndexToFieldTypeAndNameToFieldValueStores < ActiveRecord::Migration
  def change
    add_index(:field_value_stores, [:field_type, :name], unique: true)
  end
end

