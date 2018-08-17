class Agents::Branches::AssignedAgents::Quote < ActiveRecord::Base
  include PgSearch
  belongs_to :agent, class_name: 'Agents::Branches::AssignedAgent', foreign_key: 'agent_id'

  SERVICES_REQUIRED_HASH = {
    true: 'Ala Carte',
    false: 'Fixed Price'
  }

  STATUS_HASH = {
    'New' => 1,
    'Lost' => 2,
    'Won' => 3
  }

  SOURCE_MAP = {
    vendor: 0,
    agent: 1
  }

  REVERSE_SOURCE_MAP = SOURCE_MAP.invert

  #MAX_AGENT_QUOTE_WAIT_TIME = 48.hours
  MAX_AGENT_QUOTE_WAIT_TIME = 10.minutes
  #MAX_VENDOR_QUOTE_WAIT_TIME = 72.hours
  MAX_VENDOR_QUOTE_WAIT_TIME = 20.minutes

  VENDOR_LIMIT = 30
  REVERSE_SERVICES_REQUIRED_HASH = SERVICES_REQUIRED_HASH.invert

  REVERSE_STATUS_HASH = STATUS_HASH.invert

  #### A new quote needs to be made whenever status of a property is changed to green
  #### to the assigned agent or all the agents

  def compute_price
    price = 0
    if quote_details.is_a?(Array) && quote_details.first['price']
      price = quote_details.inject(0){|t,v| t+= v['price'].to_i }
    else
      quote_details.each do |key, inner_hash|
        inner_hash['list_of_services'].each do |inner_inner_hash|
          price += inner_inner_hash['price'].to_i
        end
      end
    end
 
    price
  end
  pg_search_scope :search_address_and_vendor_details, :against => [:vendor_name, :vendor_email, :address], :using => {
                    :tsearch => {:any_word => true}
                  }

  pg_search_scope :search_address_vendor_details_and_agent, :against => [:vendor_name, :vendor_email, :address, :agent_email, :agent_name], :using => {
                    :tsearch => {:any_word => true}
                  }
end
