class Developers::Branches::Employee < ActiveRecord::Base
  has_secure_password
  belongs_to :branch, class_name: 'Developers::Branch'
end
