module Agents
  class Branch < ActiveRecord::Base
    belongs_to :agent, class_name: 'Agent'
    def self.table_name
      'agents_branches'
    end
  end
end
