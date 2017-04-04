class PropertyService

  attr_accessor :udprn

  def initialize(udprn)
    @udprn = udprn
  end

  def attach_vendor_to_property(vendor_id)
    details = PropertyDetails.details(udprn)
    district = details['_source']['district']
    client = Elasticsearch::Client.new host: Rails.configuration.remote_es_host
    PropertyDetails.update_details(client, udprn, { vendor_id: vendor_id , claimed_at: Time.now.to_s })
    Vendor.find(vendor_id).update_attributes(property_id: udprn)
    Agents::Branches::AssignedAgents::Lead.create(district: district, property_id: udprn, vendor_id: vendor_id)
  end

  def claim_new_property(agent_id)
    message, status = nil
    lead = Agents::Branches::AssignedAgents::Lead.where(property_id: udprn.to_i, agent_id: nil).last
    if lead
      lead.agent_id = agent_id
      lead.save!
      message = 'You have claimed this property Successfully. Now survey this property within 30 days'
      status = 200
    else
      message = 'Sorry, this property has already been claimed'
      status = 400
    end
    return message, status
  end
end