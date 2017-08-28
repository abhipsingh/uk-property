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

  def insert_events(agent_id1, property_id, buyer_id, message, type_of_match, property_status_type, event)
    property_id = property_id.to_i
    type_of_match = type_of_match.to_i
    property_status_type = property_status_type.to_i
    event = event.to_i
    agent_id = details['_source']['agent_id'] || 1234
    response = {}
    # Rails.logger.info("prop #{property_id}  type of match #{type_of_match} prop status #{property_status_type} event #{event}")
    #### Defend against null cases
    # Rails.logger.info("(#{agent_id1}, #{property_id}, #{buyer_id}, #{message}, #{type_of_match}, #{property_status_type}, #{event})")
    if property_id && buyer_id && type_of_match && property_status_type && event
      if !Events::Track::TRACKING_TYPE_MAP.keys.include?(Trackers::Buyer::REVERSE_EVENTS[event.to_i])
        date = Date.today.to_s
        month = Date.today.month
        time = Time.now.strftime("%Y-%m-%d %H:%M:%S").to_s
        buyer_id ||= 1
        buyer = PropertyBuyer.where(id: buyer_id).select([:name, :email, :mobile]).last
        buyer ||= PropertyBuyer.find(1)
        details = PropertyDetails.details(property_id).with_indifferent_access
        address = PropertyDetails.address(details['_source']) rescue ""
        agent = Agents::Branches::AssignedAgent.where(id: agent_id).select([:name, :email, :mobile]).last
        message = nil if message == 'NULL'
        agent_name = agent.name if agent
        agent_email = agent.email if agent
        agent_mobile = agent.mobile if agent
        property_status_type = Trackers::Buyer::PROPERTY_STATUS_TYPES[details['_source']['property_status_type']]
        attrs_list = {
          agent_id: agent_id,
          buyer_id: buyer_id,
          message: message,
          udprn: property_id,
          type_of_match: type_of_match,
          agent_name: agent_name,
          agent_email: agent_email,
          agent_mobile: agent_mobile,
          buyer_name: buyer.name,
          buyer_email: buyer.email,
          buyer_mobile: buyer.mobile,
          address: address,
          event: event,
          property_status_type: property_status_type
        }
        Event.create!(attrs_list)
        # Rails.logger.info("prop #{property_id}  type of match #{type_of_match} prop status #{property_status_type} event #{event}")
        response = {}
  
        if event == Trackers::Buyer::EVENTS[:sold]
          host = Rails.configuration.remote_es_host
          client = Elasticsearch::Client.new host: host
          update_hash = { property_status_type: 'Red', vendor_id: buyer_id , sold: true }
          response = PropertyDetails.update_details(client, property_id, update_hash)
        end
      else
        type_of_tracking = Trackers::Buyer::REVERSE_EVENTS[event.to_i]
        enum_type_of_tracking = Events::Track::TRACKING_TYPE_MAP[type_of_tracking]
        address_attr = Events::Track::ADDRESS_ATTRS.select{ |t| !type_of_tracking.to_s.index(t.to_s).nil? }.last
        if address_attr
          hash_str = Events::Track.send("#{address_attr}_hash", details)
          Events::Track.create!(type_of_tracking: enum_type_of_tracking, hash_str: hash_str, agent_id: agent_id, buyer_id: buyer_id, udprn: property_id)
        end
      end
    end
    response
  end

end
