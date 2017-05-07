class AddAttributesToCrawledProperties < ActiveRecord::Migration
  def change
    add_column(:agents_branches_crawled_properties, :thoroughfare_descriptor, :string)
    add_column(:agents_branches_crawled_properties, :double_dependent_locality, :string)
    add_column(:agents_branches_crawled_properties, :dependent_locality, :string)
    add_column(:agents_branches_crawled_properties, :dependent_thoroughfare_description, :string)

    add_column(:agents_branches_crawled_properties_buys, :thoroughfare_descriptor, :string)
    add_column(:agents_branches_crawled_properties_buys, :double_dependent_locality, :string)
    add_column(:agents_branches_crawled_properties_buys, :dependent_locality, :string)
    add_column(:agents_branches_crawled_properties_buys, :dependent_thoroughfare_description, :string)

    add_column(:agents_branches_crawled_properties_rents, :thoroughfare_descriptor, :string)
    add_column(:agents_branches_crawled_properties_rents, :double_dependent_locality, :string)
    add_column(:agents_branches_crawled_properties_rents, :dependent_locality, :string)
    add_column(:agents_branches_crawled_properties_rents, :dependent_thoroughfare_description, :string)
  end
end
