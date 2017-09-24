class Event < ActiveRecord::Base
  include PgSearch
  pg_search_scope :search_address_and_buyer_details, :against => [:buyer_name ], :using => {
                    :tsearch => {:any_word => true}
                  }

  pg_search_scope :search_address_buyer_details_and_agent, :against => [:buyer_name, :agent_name], :using => {
                    :tsearch => {:any_word => true}
                  }
  pg_search_scope :search_address_and_agent_details, :against => [:agent_name ], :using => {
                  :tsearch => {:any_word => true}
                }               
  #default_scope { where(is_deleted: false) }
  default_scope { where(is_archived: false) }

end
