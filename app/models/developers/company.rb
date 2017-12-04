class Developers::Company < ActiveRecord::Base
  belongs_to :group, class_name: 'Developers::Group'
  has_many :branches, foreign_key: 'company_id'
end
