class CreateVisitedUrls < ActiveRecord::Migration
  def change
    create_table :visited_urls do |t|
      t.string :url

      t.timestamps null: false
    end
    add_index(:visited_urls, :url)
  end
end
