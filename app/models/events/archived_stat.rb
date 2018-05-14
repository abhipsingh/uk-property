module Events
  class ArchivedStat
    
    CACHE_KEY_PREFIX = 'archived_property_stats_'
    ENQUIRY_SEPERATOR = ','
    VIEWS_SEPERATOR = '|'
  
    attr_accessor :id
  
    def initialize(udprn: property_id)
      @id = udprn
    end
  
    def cache_key_value
      CACHE_KEY_PREFIX + @id.to_s
    end

    def fetch_value
      ardb_client = Rails.configuration.ardb_client
      cache_key = CACHE_KEY_PREFIX + @id.to_s
      ardb_client.get(cache_key).to_s
    end
  
    def set_value(value)
      ardb_client = Rails.configuration.ardb_client
      cache_key = CACHE_KEY_PREFIX + @id.to_s
      ardb_client.set(cache_key, value)
    end

    def transfer_from_unarchived_stats
      unarchived_stat = Events::EnquiryStatProperty.new(udprn: @id)
      unarchived_value = unarchived_stat.fetch_value
      archived_value = fetch_value

      ### Unarchived views and enquiries
      unarchived_parts = unarchived_value.split(VIEWS_SEPERATOR)
      unarchived_views = unarchived_parts[1].to_i
      unarchived_requested_floorplans = unarchived_parts[2].to_i
      unarchived_enquiries = unarchived_parts[0].to_s.split(ENQUIRY_SEPERATOR)
      form_value_str(unarchived_enquiries)

      ### Archived views and enquiries
      archived_parts = archived_value.split(VIEWS_SEPERATOR)
      archived_views = archived_parts[1].to_i
      archived_requested_floorplans = archived_parts[2].to_i
      archived_enquiries = archived_parts[0].split(ENQUIRY_SEPERATOR)
      form_value_str(archived_enquiries)
      
      Event::ENQUIRY_EVENTS.each_with_index do |event, index|
        archived_enquiries[index] += unarchived_enquiries[index]
        unarchived_enquiries[index] = 0
      end
      archived_enquiries[Event::ENQUIRY_EVENTS.length] += unarchived_enquiries[Event::ENQUIRY_EVENTS.length]
      unarchived_enquiries[Event::ENQUIRY_EVENTS.length] = 0

      archived_views = archived_views + unarchived_views
      archived_requested_floorplans = archived_requested_floorplans + unarchived_requested_floorplans
      archived_value = [ archived_enquiries[0..Event::ENQUIRY_EVENTS.length].join(ENQUIRY_SEPERATOR), archived_views.to_s, archived_requested_floorplans.to_s ].join(VIEWS_SEPERATOR)
      set_value(archived_value)

      unarchived_views = 0
      unarchived_requested_floorplans = 0
      unarchived_value = [ unarchived_enquiries[0..Event::ENQUIRY_EVENTS.length].join(ENQUIRY_SEPERATOR), unarchived_views.to_s, unarchived_requested_floorplans.to_s ].join(VIEWS_SEPERATOR)
      unarchived_stat.set_value(unarchived_value)
    end
    
    def update_enquiries(event, count)
      value_str = fetch_value
      value_parts = value_str.split(VIEWS_SEPERATOR)
      views = value_parts[1].to_i
      requested_floorplans = value_parts[2].to_i
      enquiries = value_parts[0].to_s.split(ENQUIRY_SEPERATOR)
      form_value_str(enquiries)
      enquiry_index = Event::ENQUIRY_EVENTS.index(Event::REVERSE_EVENTS[event])
      enquiries[enquiry_index] += 1
      enquiries[Event::ENQUIRY_EVENTS.length] += 1
      value = [ enquiries.join(ENQUIRY_SEPERATOR), views.to_s, requested_floorplans.to_s ].join(VIEWS_SEPERATOR)
      set_value(value)
    end
  
    def form_value_str(enquiries)
      sum = 0
      Event::ENQUIRY_EVENTS.each_with_index do |t, index|
        enquiries[index] = enquiries[index].to_i 
        sum += enquiries[index].to_i
      end
      enquiries[Event::ENQUIRY_EVENTS.length] = sum
    end
  
    def update_views
      value_str = fetch_value
      value_parts = value_str.split(VIEWS_SEPERATOR)
      views = value_parts[1].to_i
      views += 1
      value = [ value_parts[0], views.to_s, value_parts[2] ].join(VIEWS_SEPERATOR)
      set_value(value)
    end
  
    def views
      value_str = fetch_value
      value_str.split(VIEWS_SEPERATOR)[1].to_i
    end

    def requested_floorplans
      value_str = fetch_value
      value_str.split(VIEWS_SEPERATOR)[2].to_i
    end

    def update_requested_floorplans
      value_str = fetch_value
      value_parts = value_str.split(VIEWS_SEPERATOR)
      requested_floorplans = value_parts[2].to_i
      requested_floorplans += 1
      value = [ value_parts[0], value_parts[1], requested_floorplans.to_s ].join(VIEWS_SEPERATOR)
      set_value(value)
    end
  
    def enquiries
      value_str = fetch_value
      value_str.split(VIEWS_SEPERATOR)[0].to_s.split(ENQUIRY_SEPERATOR).last.to_i
    end
  
    def specific_enquiry_count(event)
      value_str = fetch_value
      enquiry_index = Event::ENQUIRY_EVENTS.index(event)
      value_str.split(VIEWS_SEPERATOR)[0].to_s.split(ENQUIRY_SEPERATOR)[enquiry_index].to_i
    end
  
  end
end

