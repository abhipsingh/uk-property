class CreateFrUrls < ActiveRecord::Migration
  def change
    create_table :fr_urls do |t|
      t.string :url
      t.boolean :processed
    end
  end
end
