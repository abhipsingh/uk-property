class Agents::Branches::AssignedAgents::Lead < ActiveRecord::Base
  belongs_to :agent, class_name: '::Agents::Branches::AssignedAgent'
  belongs_to :vendor
  
  VERIFICATION_DAY_LIMIT = 1.hours

  SOURCE_MAP = {
    crawled: 1,
    family: 2,
    non_crawled: 3,
    mailshot: 4
  }

end
