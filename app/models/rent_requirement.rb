class RentRequirement < ActiveRecord::Base
  belongs_to :buyer, class_name: 'PropertyBuyer'
end

