module EventsHelper
  def process_image(result)
    result = result.with_indifferent_access
    request_params = {
      size: '1200x800',
      location: result[:address],
      fov: 120,
      pitch: 0,
      key: 'AIzaSyBfcSipqHZEZooyoKqxpLzVu3u-NuEdIt8'
    }
    result = result.with_indifferent_access
    s3 = Aws::S3::Resource.new(region: 'ap-south-1')
    file_name = "fov_120_#{result[:udprn]}.jpg"
    bucket = Aws::S3::Bucket.new('google-street-view-prophety', region: 'ap-south-1')
    obj = bucket.object("#{result[:udprn]}/#{file_name}")
    udprn = result[:udprn]
    if !obj.exists?
      process_each_address(udprn, request_params)
    end
    obj.public_url   
  end

  def process_each_address(udprn, request_params)
    url = 'https://maps.googleapis.com/maps/api/streetview' + '?' + request_params.to_query
    uri = URI.parse(URI.encode(url))
    begin
      make_request(request_params, uri, udprn)
      Rails.logger.info("STREET_VIEW_CRAWLING_SUCESS_FOR_#{udprn}")
    rescue StandardError => e
      Rails.logger.error("STREET_VIEW_CRAWLING_FAILED_FOR_#{udprn}")
    end
  end

  def make_request(req, uri, udprn)
    file_name = "fov_120_#{udprn}.jpg"
    Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
      request = Net::HTTP::Get.new uri
      http.request request do |response|
        open file_name, 'wb' do |io|
          response.read_body do |chunk|
            io.write chunk
          end
        end
      end
    end
    s3 = Aws::S3::Resource.new(region: 'ap-south-1')
    obj = s3.bucket("google-street-view-prophety").object("#{udprn}/#{file_name}")
    res = obj.upload_file(file_name, acl: 'public-read')
    File.delete(file_name) if res
  end

  def insert_events(agent_id, property_id, buyer_id, message, type_of_match, property_status_type, event)
    property_id = property_id.to_i
    type_of_match = type_of_match.to_i
    event = event.to_i
    response = {}
    # Rails.logger.info("prop #{property_id}  type of match #{type_of_match} prop status #{property_status_type} event #{event}")
    #### Defend against null cases
    # Rails.logger.info("(#{agent_id1}, #{property_id}, #{buyer_id}, #{message}, #{type_of_match}, #{property_status_type}, #{event})")
    if property_id && type_of_match && event
      if Event::ENQUIRY_EVENTS.include?(Event::REVERSE_EVENTS[event])
        date = Date.today.to_s
        month = Date.today.month
        time = Time.now.strftime("%Y-%m-%d %H:%M:%S").to_s
        buyer = PropertyBuyer.where(id: buyer_id).select([:name, :email, :mobile]).last

        attrs_list = {
          agent_id: agent_id,
          buyer_id: buyer_id,
          udprn: property_id,
          type_of_match: type_of_match,
          event: event
        }

        created_event = Event.create!(attrs_list)
        enquiries = Enquiries::PropertyService.process_enquiries_result([created_event])
        response[:enquiries] = enquiries


        ### Update counts enquiry wise for both property and buyer
        Events::EnquiryStatProperty.new(udprn: property_id).update_enquiries(event)
        #Events::EnquiryStatBuyer.new(buyer_id: buyer_id).update_enquiries(event) if !buyer_id.nil?

        ### Clear the cache. List all cached methods which has cache key as agent_id/udprn
        ardb_client = Rails.configuration.ardb_client
        ardb_client.del("cache_#{agent_id}_agent_new_enquiries") if agent_id
        ardb_client.del("cache_#{property_id}_enquiries")
        ardb_client.del("cache_#{property_id}_interest_info")
        ardb_client.del("cache_#{buyer_id}_history_enquiries")

        # Rails.logger.info("prop #{property_id}  type of match #{type_of_match} prop status #{property_status_type} event #{event}")
      elsif Event::TRACKING_EVENTS.include?(Event::REVERSE_EVENTS[event])
        type_of_tracking = Event::REVERSE_EVENTS[event.to_i]
        enum_type_of_tracking = Events::Track::TRACKING_TYPE_MAP[type_of_tracking]
        address_attr = Events::Track::ADDRESS_ATTRS.select{ |t| !type_of_tracking.to_s.index(t.to_s).nil? }.last
        if address_attr
          buyer = PropertyBuyer.find(buyer_id)
          details = PropertyDetails.details(property_id)
          hash_str = Events::Track.send("#{address_attr}_hash", details[:_source])
          tracking_event = Events::Track.new(type_of_tracking: enum_type_of_tracking, hash_str: hash_str, agent_id: agent_id, buyer_id: buyer_id, udprn: property_id)
          tracking_event.premium = buyer.is_premium
          tracking_event.save!
        end
      elsif Event::QUALIFYING_STAGE_EVENTS.include?(Event::REVERSE_EVENTS[event])

        ### Update stage of the enquiry
        if Event::EVENTS[:offer_made_stage] == event

          if message[:offer_price] || message[:offer_date]
            original_enquiries = Event.where(buyer_id: buyer_id).where(udprn: property_id).where(is_archived: false)
            update_hash = { stage: event }
            update_hash[:offer_price] = message[:offer_price] if message[:offer_price]
            update_hash[:offer_date] = message[:offer_date] if message[:offer_date]
            original_enquiries.update_all(update_hash) 
            enquiries = Enquiries::PropertyService.process_enquiries_result(original_enquiries)
            response[:enquiries] = enquiries
          else
            response[:enquiries] = []
          end
  
        elsif Event::EVENTS[:viewing_stage] == event

          if message[:scheduled_viewing_time]
            original_enquiries = Event.where(buyer_id: buyer_id).where(udprn: property_id).where(is_archived: false)
            original_enquiries.update_all(stage: event, scheduled_visit_time: Time.parse(message[:scheduled_viewing_time])) 
            enquiries = Enquiries::PropertyService.process_enquiries_result(original_enquiries)
            response[:enquiries] = enquiries
          else
            response[:enquiries] = []
          end
  
        elsif Event::EVENTS[:completion_stage] == event

          if message[:expected_completion_date]
            original_enquiries = Event.where(buyer_id: buyer_id).where(udprn: property_id).where(is_archived: false)
            update_hash = { stage: event, expected_completion_date: Date.parse(message[:expected_completion_date]) }
            update_hash[:offer_price] = message[:offer_price] if message[:offer_price]
            original_enquiries.update_all(update_hash)
            enquiries = Enquiries::PropertyService.process_enquiries_result(original_enquiries)
            response[:enquiries] = enquiries
          else
            response[:enquiries] = []
          end

        elsif Event::EVENTS[:closed_won_stage] == event

          service = SoldPropertyEventService.new(udprn: property_id, buyer_id: buyer_id, final_price: message[:final_price], agent_id: agent_id)
          response[:enquiries] = service.close_enquiry(completion_date: message[:completion_date])
          Event.where(buyer_id: buyer_id).where(udprn: property_id).where(is_archived: false).update_all(offer_price: message[:offer_price]) if message[:offer_price]

        else

          original_enquiries = Event.where(buyer_id: buyer_id).where(udprn: property_id).where(is_archived: false)
          original_enquiries.update_all(stage: event)
          enquiries = Enquiries::PropertyService.process_enquiries_result(original_enquiries)
          response[:enquiries] = enquiries

        end

      elsif Event::HOTNESS_EVENTS.include?(Event::REVERSE_EVENTS[event])

        original_enquiries = Event.where(buyer_id: buyer_id).where(udprn: property_id).where(is_archived: false)
        original_enquiries.update_all(rating: event)
        enquiries = Enquiries::PropertyService.process_enquiries_result(original_enquiries)
        response[:enquiries] = enquiries
        ### Update hotness of a property

      elsif event == Event::EVENTS[:viewed]

        Events::EnquiryStatProperty.new(udprn: property_id).update_views
        #Events::EnquiryStatBuyer.new(buyer_id: buyer_id).update_views if !buyer_id.nil?
        Events::View.create!(udprn: property_id, month: Time.now.month, buyer_id: buyer_id)

        ### Delete the interest info cache
        ardb_client = Rails.configuration.ardb_client
        ardb_client.del("cache_#{property_id}_interest_info")

      elsif event == Event::EVENTS[:deleted]
        Events::IsDeleted.create!(udprn: property_id, buyer_id: buyer_id, vendor_id: vendor_id, agent_id: agent_id)  
      end
        

    end
    response
  end

end

