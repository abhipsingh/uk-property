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
      unarchived_views = unarchived_value.split(VIEWS_SEPERATOR)[1].to_i
      unarchived_enquiries = unarchived_value.split(VIEWS_SEPERATOR)[0].to_s.split(ENQUIRY_SEPERATOR)
      form_value_str(unarchived_enquiries)

      ### Archived views and enquiries
      archived_views = archived_value.split(VIEWS_SEPERATOR)[1].to_i
      archived_enquiries = archived_value.split(VIEWS_SEPERATOR)[0].to_s.split(ENQUIRY_SEPERATOR)
      form_value_str(archived_enquiries)
      
      Event::ENQUIRY_EVENTS.each_with_index do |event, index|
        archived_enquiries[index] += unarchived_enquiries[index]
        unarchived_enquiries[index] = 0
      end
      archived_enquiries[Event::ENQUIRY_EVENTS.length] += unarchived_enquiries[Event::ENQUIRY_EVENTS.length]
      unarchived_enquiries[Event::ENQUIRY_EVENTS.length] = 0

      archived_views = archived_views + unarchived_views
      archived_value = archived_enquiries[0..Event::ENQUIRY_EVENTS.length].join(ENQUIRY_SEPERATOR) + VIEWS_SEPERATOR + archived_views.to_s
      set_value(archived_value)

      unarchived_views = 0
      unarchived_value = unarchived_enquiries[0..Event::ENQUIRY_EVENTS.length].join(ENQUIRY_SEPERATOR) + VIEWS_SEPERATOR + unarchived_views.to_s
      unarchived_stat.set_value(unarchived_value)
    end
    
    def update_enquiries(event, count)
      value_str = fetch_value
      views = value_str.split(VIEWS_SEPERATOR)[1].to_i
      enquiries = value_str.split(VIEWS_SEPERATOR)[0].to_s.split(ENQUIRY_SEPERATOR)
      form_value_str(enquiries)
      enquiry_index = Event::ENQUIRY_EVENTS.index(Event::REVERSE_EVENTS[event])
      enquiries[enquiry_index] += 1
      enquiries[Event::ENQUIRY_EVENTS.length] += 1
      value = enquiries.join(ENQUIRY_SEPERATOR) + VIEWS_SEPERATOR + views.to_s
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
      views = value_str.split(VIEWS_SEPERATOR)[1].to_i
      views += 1
      value = value_str.split(VIEWS_SEPERATOR)[0].to_s + VIEWS_SEPERATOR + views.to_s
      set_value(value)
    end
  
    def views
      value_str = fetch_value
      value_str.split(VIEWS_SEPERATOR)[1].to_i
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
  
    def update_view_and_enquiry(event)
      value_str = fetch_value
      views = value_str.split(VIEWS_SEPERATOR)[1].to_i + 1
      enquiries = value_str.split(VIEWS_SEPERATOR)[0].to_s.split(ENQUIRY_SEPERATOR)
      form_value_str(enquiries)
      enquiry_index = Event::ENQUIRY_EVENTS.index(Event::REVERSE_EVENTS[event])
      enquiries[enquiry_index] += 1
      enquiries[Event::ENQUIRY_EVENTS.length] += 1
      value = enquiries.join(ENQUIRY_SEPERATOR) + VIEWS_SEPERATOR + views.to_s
      set_value(value)
    end
  
  end
end

