class Agent < ActiveRecord::Base
  has_many :branches, class_name: 'Agents::Branch'
end
