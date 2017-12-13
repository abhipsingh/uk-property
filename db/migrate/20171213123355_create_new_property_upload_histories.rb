class CreateNewPropertyUploadHistories < ActiveRecord::Migration
  def change
    create_table :new_property_upload_histories do |t|
      t.string :property_type
      t.integer :beds
      t.integer :baths
      t.integer :receptions
      t.string :assigned_agent_email
      t.integer :udprn
      t.integer :developer_id
      t.timestamp :created_at, null: false
    end
  end
end

