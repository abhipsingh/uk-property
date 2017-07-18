class PropertyService

  attr_accessor :udprn

  #### AGENT_STATUS_MAP
  #### {
  ####    1 => 'Lead',
  ####    2 => 'AssignedAgent'
  #### }
  MANDATORY_ATTRS = [:property_type, :beds, :baths, :receptions, :pictures, :floorplan_url, :current_valuation, :inner_area, :outer_area]
  AGENT_STATUS = {
    lead: 1,
    assigned: 2
  }

  def initialize(udprn)
    @udprn = udprn
  end

  def attach_vendor_to_property(vendor_id, details={}, property_for='Sale')
    property_details = PropertyDetails.details(udprn)
    details.merge!(property_details['_source'])
    district = details['district']
    Vendor.find(vendor_id).update_attributes(property_id: udprn)
    create_lead_and_update_vendor_details(district, udprn, vendor_id, details, property_for)
  end

  def create_lead_and_update_vendor_details(district, udprn, vendor_id, details, property_for='Sale')
    details['property_status_type'] = 'Rent' if property_for != 'Sale'
    client = Elasticsearch::Client.new host: Rails.configuration.remote_es_host
    property_status_type = Trackers::Buyer::PROPERTY_STATUS_TYPES[details['property_status_type']]
    Agents::Branches::AssignedAgents::Lead.create(district: district, property_id: udprn, vendor_id: vendor_id, property_status_type: property_status_type)
    details[:vendor_id] = vendor_id
    details[:claimed_at] = Time.now.to_s
    PropertyDetails.update_details(client, udprn, details)
  end

  def claim_new_property(agent_id)
    message, status = nil
    lead = Agents::Branches::AssignedAgents::Lead.where(property_id: udprn.to_i, agent_id: nil).last
    if lead
      lead.agent_id = agent_id
      lead.save!
      client = Elasticsearch::Client.new host: Rails.configuration.remote_es_host
      update_hash = { agent_id: agent_id, agent_status: 1 }
      details, status = PropertyDetails.update_details(client, udprn.to_i, update_hash)
      vendor_id = lead.vendor_id
      message = 'You have claimed this property successfully. Now survey this property within 7 days'
      address = nil
      VendorService.new(vendor_id).send_email_following_agent_lead(agent_id, address)
      status = 200
    else
      message = 'Sorry, this property has already been claimed'
      status = 400
    end
    return message, status
  end

  def filter_helper(attr_hash)
    filter_hash = {
      filter: {
        and: {
          filters: []
        }
      }
    }
    attr_hash.each { |key, val| filter_hash[:filter][:and][:filters].push({ term: { key => val } })}
    api = PropertySearchApi.new(filtered_params: {})
    api.query = filter_hash
    body, status = api.fetch_data_from_es
    body
  end

  def edit_details(details, agent)
    client = Elasticsearch::Client.new(host: Rails.configuration.remote_es_host)
    details = details.with_indifferent_access
    update_hash = {}
    attributes = [
                  :property_type, :beds, :baths, :receptions, :property_style, :tenure, :floors, :listed_status,
                  :year_built, :central_heating, :parking_type, :outside_space_type, :additional_features, :decorative_condition,
                  :council_tax_band, :lighting_cost, :lighting_cost_unit_type, :heating_cost, :heating_cost_unit_type,
                  :hot_water_cost, :hot_water_cost_unit_type, :annual_ground_water_cost, :annual_service_charge,
                  :resident_parking_cost, :other_costs, :total_cost_per_month, :total_cost_per_year, :improvement_types, :dream_price,
                  :current_valuation, :floorplan_url, :pictures, :property_sold_status, :agreed_sale_value,
                  :expected_completion_date, :actual_completion_date, :new_owner_email_id, :vendor_address, :property_status_type,
                  :inner_area, :outer_area, :property_brochure_url, :video_walkthrough_url, :dream_price, :asking_price, :offers_price,
                  :fixed_price, :offers_over, :area_type
                ]
    earlier_details = details.deep_dup
    property_details = PropertyDetails.details(@udprn)['_source'].with_indifferent_access
    details.merge!(property_details)
    attributes.each do |attribute|
      update_hash[attribute] = earlier_details[attribute] if earlier_details[attribute]
    end

    ### Assume that details have been completed and are validated.
    ### TODO: Fix validations and delay assigning the attribute till validations are
    ### complete.
    update_hash[:details_completed] = false
    details_completed = MANDATORY_ATTRS.all?{|attr| details.has_key?(attr) && !details[attr].nil? }
    update_hash[:details_completed] = true if details_completed

    ### Send the report to the vendor if the agent has submitted the attributes after winning the lead
    ### the details are complete
    vendor_id = details[:vendor_id]
    agent_id = details[:agent_id]
    cond = !vendor_id.nil? && !agent_id.nil? && details[:agent_status] == AGENT_STATUS[:lead] && details_completed
    VendorService.new(vendor_id).send_email_following_agent_details_submission(agent_id, details) if cond
    PropertyDetails.update_details(client, udprn, update_hash) if !update_hash.empty?
    PropertyDetails.details(udprn)['_source']
  end

  def attach_assigned_agent(agent_id)
    client = Elasticsearch::Client.new(host: Rails.configuration.remote_es_host)
    agent = Agents::Branches::AssignedAgent.find(agent_id)
    lead = Agents::Branches::AssignedAgents::Lead.where(agent_id: agent_id, property_id: udprn).first
    branch = agent.branch
    raise StandardError, "Backend error in leads #{agent_id} #{@udprn}" if lead.nil?
    lead.submitted = true
    lead.save!
    details = {}
		details['assigned_agent_name'] = agent.name
    details['assigned_agent_email'] = agent.email
    details['assigned_agent_mobile'] = agent.mobile
    details['assigned_agent_office_number'] = agent.office_phone_number
    details['assigned_agent_image_url'] = agent.image_url
    details['assigned_agent_branch_name'] = branch.name
		details['assigned_agent_branch_number'] = branch.phone_number
    details['assigned_agent_branch_address'] = branch.address
    details['assigned_agent_branch_logo'] = branch.image_url
    details['assigned_agent_branch_email'] = branch.email
    details['details_completed'] = true
    details['agent_status'] = AGENT_STATUS[:assigned]
    PropertyDetails.update_details(client, udprn, details)
  end
  
  def is_property_is_in_lead_stage?(details)
  end

  def self.post_url(index_name, type_name, endpoint='_search', query={})
    es_url = Rails.configuration.remote_es_url
    uri = URI.parse(URI.encode("#{es_url}/#{index_name}/#{type_name}/#{endpoint}"))
    query = (query == {}) ? "" : query.to_json
    http = Net::HTTP.new(uri.host, uri.port)
    result = http.post(uri,query)
    body = result.body
    status = result.code
    return body, status
  end
end

