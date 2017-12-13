class Uk::Property < ActiveRecord::Base
  attr_accessor :vendor_present, :address, :vendor_id

  def self.searchable_columns
    [:post_code]
  end
end
