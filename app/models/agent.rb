class Agent < ActiveRecord::Base
  has_many :branches, class_name: '::Agents::Branch', foreign_key: 'agent_id'
  belongs_to :group, class_name: 'Agents::Group'
  attr_accessor :children_vanity_urls

  def vanity_url
    company_vanity_url = self.name.downcase.gsub(/[a-z ]+/).to_a.join('').split(' ').join('-')
    company_vanity_url = [ company_vanity_url ].join('-')
    Rails.configuration.frontend_production_url + '/companies/details/' + company_vanity_url + '-' + self.id.to_s
  end

  def children_vanity_urls
    branches = self.branches
    branches.map do |branch|
      { name: branch.name, vanity_url: branch.vanity_url }
    end
  end

end
