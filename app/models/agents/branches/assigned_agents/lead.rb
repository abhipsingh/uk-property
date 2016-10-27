class Agents::Branches::AssignedAgents::Lead < ActiveRecord::Base
  belongs_to :agent, class_name: 'Agents::Branches::AssignedAgent'
end
