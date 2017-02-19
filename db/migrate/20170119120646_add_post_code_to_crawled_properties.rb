class AddPostCodeToCrawledProperties < ActiveRecord::Migration
  def change
    add_column(:agents_branches_crawled_properties, :postcode, :string)
    add_index(:agents_branches_crawled_properties, :postcode)
  end
end
