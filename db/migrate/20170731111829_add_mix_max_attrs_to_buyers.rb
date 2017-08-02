class AddMixMaxAttrsToBuyers < ActiveRecord::Migration
  def change
    add_column(:property_buyers, :property_types, :string, array: true, default: '{}')
    add_column(:property_buyers, :min_beds, :integer)
    add_column(:property_buyers, :max_beds, :integer)
    add_column(:property_buyers, :min_baths, :integer)
    add_column(:property_buyers, :max_baths, :integer)
    add_column(:property_buyers, :min_receptions, :integer)
    add_column(:property_buyers, :max_receptions, :integer)
    add_column(:property_buyers, :locations, :string, array: true, default: '{}')
    add_column(:property_buyers, :biggest_problems, :string, array: true, default: '{}')
  end
end
