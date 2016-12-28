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

  REVERSE_SERVICES_REQUIRED_HASH = SERVICES_REQUIRED_HASH.invert

  REVERSE_STATUS_HASH = STATUS_HASH.invert

  #### A new quote needs to be made whenever status of a property is changed to green
  #### to the assigned agent or all the agents

  def compute_price
    price = 0
    quote_details.each do |key, inner_hash|
      price += inner_hash['price'].to_i
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