class AddAdditionalColumnsToNewPropertyUploadHistory < ActiveRecord::Migration
  def change
    add_column(:new_property_upload_histories, :features, :jsonb, default: '[]')
    add_column(:new_property_upload_histories, :description, :text)
    add_column(:new_property_upload_histories, :floorplan_urls, :jsonb, default: '[]')
  end
end

