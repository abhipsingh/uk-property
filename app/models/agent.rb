class Agent < ActiveRecord::Base
  has_many :branches, class_name: '::Agents::Branch', foreign_key: 'agent_id'
  belongs_to :group, class_name: 'Agents::Group'
end
