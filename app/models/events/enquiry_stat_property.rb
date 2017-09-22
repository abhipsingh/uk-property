class Events::EnquiryStatProperty
  
  CACHE_KEY_PREFIX = 'property_stats_'
  ENQUIRY_SEPERATOR = ','
  VIEWS_SEPERATOR = '|'

  attr_accessor :id

  def initialize(udprn: property_id)
    @id = udprn
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

  def update_enquiries(event)
    value_str = fetch_value
    views = value_str.split(VIEWS_SEPERATOR)[1].to_i
    enquiries = value_str.split(VIEWS_SEPERATOR)[0].to_s.split(ENQUIRY_SEPERATOR)
    form_value_str(enquiries)
    enquiry_index = Trackers::Buyer::ENQUIRY_EVENTS.index(Trackers::Buyer::REVERSE_EVENTS[event])
    enquiries[enquiry_index] += 1
    enquiries[Trackers::Buyer::ENQUIRY_EVENTS.length] += 1
    value = enquiries.join(ENQUIRY_SEPERATOR) + VIEWS_SEPERATOR + views.to_s
    set_value(value)
  end

  def form_value_str(enquiries)
    sum = 0
    Trackers::Buyer::ENQUIRY_EVENTS.each_with_index do |t, index|
      enquiries[index] = enquiries[index].to_i 
      sum += enquiries[index].to_i
    end
    enquiries[Trackers::Buyer::ENQUIRY_EVENTS.length] = sum
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
    enquiry_index = Trackers::Buyer::ENQUIRY_EVENTS.index(Trackers::Buyer::REVERSE_EVENTS[event])
    value_str.split(VIEWS_SEPERATOR)[0].to_s.split(ENQUIRY_SEPERATOR)[enquiry_index].to_i
  end

  def update_view_and_enquiry(event)
    value_str = fetch_value
    views = value_str.split(VIEWS_SEPERATOR)[1].to_i + 1
    enquiries = value_str.split(VIEWS_SEPERATOR)[0].to_s.split(ENQUIRY_SEPERATOR)
    form_value_str(enquiries)
    enquiry_index = Trackers::Buyer::ENQUIRY_EVENTS.index(Trackers::Buyer::REVERSE_EVENTS[event])
    enquiries[enquiry_index] += 1
    enquiries[Trackers::Buyer::ENQUIRY_EVENTS.length] += 1
    value = enquiries.join(ENQUIRY_SEPERATOR) + VIEWS_SEPERATOR + views.to_s
    set_value(value)
  end

end
