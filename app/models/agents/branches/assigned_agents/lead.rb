class Agents::Branches::AssignedAgents::Lead < ActiveRecord::Base
  belongs_to :agent, class_name: '::Agents::Branches::AssignedAgent'
  belongs_to :vendor
  
  VERIFICATION_DAY_LIMIT = 7

end
