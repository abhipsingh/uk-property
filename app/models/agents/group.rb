class Agents::Group < ActiveRecord::Base

	has_many :agents, class_name: '::Agent'

  def self.table_name
    'agents_groups'
  end
end
