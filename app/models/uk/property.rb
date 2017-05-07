class Uk::Property < ActiveRecord::Base
  def self.searchable_columns
    [:post_code]
  end
end
