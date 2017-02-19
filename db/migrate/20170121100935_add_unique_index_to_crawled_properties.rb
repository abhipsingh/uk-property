class AddUniqueIndexToCrawledProperties < ActiveRecord::Migration
  def change
    add_index(:agents_branches_crawled_properties, :zoopla_id, {unique: true})
  end
end
