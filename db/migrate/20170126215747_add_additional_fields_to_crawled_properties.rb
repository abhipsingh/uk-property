class AddAdditionalFieldsToCrawledProperties < ActiveRecord::Migration
  def change
    add_column(:agents_branches_crawled_properties, :additional_details, :jsonb)
  end
end
