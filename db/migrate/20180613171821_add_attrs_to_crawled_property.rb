class AddAttrsToCrawledProperty < ActiveRecord::Migration
  def change
    add_column(:agents_branches_crawled_properties, :property_status_type, :string)
    add_column(:agents_branches_crawled_properties, :property_type, :string)
    add_column(:agents_branches_crawled_properties, :lettings, :boolean)
    add_column(:agents_branches_crawled_properties, :agent_email, :string)
    add_column(:agents_branches_crawled_properties, :vendor_email, :string)
  end
end
