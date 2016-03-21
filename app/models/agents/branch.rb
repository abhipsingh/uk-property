module Agents
  class Branch < ActiveRecord::Base
    belongs_to :agent, class_name: 'Agent'
    has_many :properties, class_name: 'Agents::Branches::CrawledProperty'
    def self.table_name
      'agents_branches'
    end
  end
end
