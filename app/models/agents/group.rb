class Agents::Group < ActiveRecord::Base

	has_many :companies, class_name: '::Agent', foreign_key: 'group_id'

  def self.table_name
    'agents_groups'
  end
end
