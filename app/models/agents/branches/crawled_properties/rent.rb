class Agents::Branches::CrawledProperties::Rent < ActiveRecord::Base
  belongs_to :agent, class_name: Agents::Branches::OnTheMarketRent
end
