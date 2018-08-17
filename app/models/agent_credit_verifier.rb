class AgentCreditVerifier < ActiveRecord::Base
  KLASSES = [ 'Agents::Branches::AssignedAgents::Quote', 'Agents::Branches::AssignedAgents::Lead', 'Rent::Quote' ]
end
