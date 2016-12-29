module EventsHelper

  def insert_events(agent_id1, property_id, buyer_id, message, type_of_match, property_status_type, event)
    property_id = property_id.to_i
    buyer_id = buyer_id.to_i
    type_of_match = type_of_match.to_i
    property_status_type = property_status_type.to_i
    event = event.to_i
    #### Defend against null cases
    if property_id && buyer_id && type_of_match && property_status_type && event
      
      date = Date.today.to_s
      month = Date.today.month
      time = Time.now.strftime("%Y-%m-%d %H:%M:%S").to_s
      buyer_id ||= 1
      buyer = PropertyBuyer.where(id: buyer_id).select([:name, :email, :mobile]).last
      details = PropertyDetails.details(property_id)
      address = PropertyDetails.address(details['_source'])
      agent_id = details['_source']['agent_id'] || 1234
      agent = Agents::Branches::AssignedAgent.where(id: agent_id).select([:name, :email, :mobile]).last
      message = nil if message == 'NULL'
      Event.create!(agent_id: agent_id,  buyer_id: buyer_id, message: message, udprn: property_id, type_of_match: type_of_match, agent_name: agent.name, agent_email: agent.email, agent_mobile: agent.mobile, buyer_name: buyer.name, buyer_email: buyer.email, buyer_mobile: buyer.mobile, address: address, event: event)
      response = {}

      if event == Trackers::Buyer::EVENTS[:sold]
        host = Rails.configuration.remote_es_host
        client = Elasticsearch::Client.new host: host
        response = client.update index: 'addresses', type: 'address', id: property_id.to_s,
                          body: { doc: { property_status_type: 'Red', vendor_id: buyer_id } }
      end
    end
    response
  end

end
