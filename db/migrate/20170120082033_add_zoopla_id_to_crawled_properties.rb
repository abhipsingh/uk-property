class AddZooplaIdToCrawledProperties < ActiveRecord::Migration
  def change
    add_column(:agents_branches_crawled_properties, :zoopla_id, :integer)
  end
end
