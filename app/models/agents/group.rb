class Agents::Group < ActiveRecord::Base

	has_many :companies, class_name: '::Agent', foreign_key: 'group_id'
  attr_accessor :children_vanity_urls

  def self.table_name
    'agents_groups'
  end

  def vanity_url
    Rails.configuration.frontend_production_url + '/groups/details/' + name.downcase.gsub(/[a-z ]+/).to_a.join('').split(' ').join('-') + '-' + self.id.to_s
  end

  def children_vanity_urls
    companies = self.companies
    companies.map do |company|
      { name: company.name, vanity_url: company.vanity_url }
    end
  end

end
