class Events::EnquiryStatProperty
  
  CACHE_KEY_PREFIX = 'property_stats_'
  ENQUIRY_SEPERATOR = ','
  VIEWS_SEPERATOR = '|'

  attr_accessor :id, :val

  def initialize(udprn: property_id)
    @id = udprn
  end

  def fetch_value
    ardb_client = Rails.configuration.ardb_client
    cache_key = CACHE_KEY_PREFIX + @id.to_s
    @val ||= ardb_client.get(cache_key).to_s
  end

  def set_value(value)
    ardb_client = Rails.configuration.ardb_client
    cache_key = CACHE_KEY_PREFIX + @id.to_s

    ### Update cache value
    @val = value
    ardb_client.set(cache_key, value)
  end

  def update_enquiries(event)
    value_str = fetch_value
    views = value_str.split(VIEWS_SEPERATOR)[1].to_i
    requested_floorplans = value_str.split(VIEWS_SEPERATOR)[2].to_i
    enquiries = value_str.split(VIEWS_SEPERATOR)[0].to_s.split(ENQUIRY_SEPERATOR)
    form_value_str(enquiries)
    enquiry_index = Event::ENQUIRY_EVENTS.index(Event::REVERSE_EVENTS[event])
    enquiries[enquiry_index] += 1
    enquiries[Event::ENQUIRY_EVENTS.length] += 1
    value = [ enquiries.join(ENQUIRY_SEPERATOR), views.to_s,  requested_floorplans.to_s ].join(VIEWS_SEPERATOR)

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
    parts = value_str.split(VIEWS_SEPERATOR)
    views = parts[1].to_i
    views += 1
    value = [ parts[0], views.to_s, parts[2] ].join(VIEWS_SEPERATOR)
    set_value(value)
  end

  def update_requested_floorplans
    event_index = Event::EVENTS[:requested_floorplan]
    update_enquiries(event_index)
  end

  def views
    value_str = fetch_value
    value_str.split(VIEWS_SEPERATOR)[1].to_i
  end

  def requested_floorplans
    specific_enquiry_count(:requested_floorplan)
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

