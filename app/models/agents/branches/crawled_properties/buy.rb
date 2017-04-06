class Agents::Branches::CrawledProperties::Buy < ActiveRecord::Base
  belongs_to :agent, class_name: Agents::Branches::OnTheMarketRent
end
