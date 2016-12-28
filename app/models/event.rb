class Event < ActiveRecord::Base
  include PgSearch
  pg_search_scope :search_address_and_buyer_details, :against => [:buyer_name, :buyer_email, :address], :using => {
                    :tsearch => {:any_word => true}
                  }

  pg_search_scope :search_address_buyer_details_and_agent, :against => [:buyer_name, :buyer_email, :address, :agent_email, :agent_name], :using => {
                    :tsearch => {:any_word => true}
                  }
  pg_search_scope :search_address_and_agent_details, :against => [:agent_name, :agent_email, :agent_mobile, :address], :using => {
                  :tsearch => {:any_word => true}
                }               
end
