class Developers::Group < ActiveRecord::Base
  has_many :companies, foreign_key: 'group_id'
end
