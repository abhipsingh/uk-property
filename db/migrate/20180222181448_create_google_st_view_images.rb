class CreateGoogleStViewImages < ActiveRecord::Migration
  def change
    create_table :google_st_view_images do |t|
      t.integer :udprn
      t.string :address
      t.boolean :crawled
    end
  end
end

