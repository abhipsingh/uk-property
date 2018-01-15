class AddUniqueIndexToNewPropertyUploadHistory < ActiveRecord::Migration
  def change
    add_index(:new_property_upload_histories, [:udprn, :developer_id], unique: true)
    add_index(:new_property_upload_histories, [:udprn], unique: true)
  end
end
