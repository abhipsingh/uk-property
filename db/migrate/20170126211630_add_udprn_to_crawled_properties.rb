class AddUdprnToCrawledProperties < ActiveRecord::Migration
  def change
    add_column(:agents_branches_crawled_properties, :udprn, :integer)
  end
end
