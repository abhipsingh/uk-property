class PropertyService

  attr_accessor :udprn

  #### AGENT_STATUS_MAP
  #### {
  ####    1 => 'Lead',
  ####    2 => 'AssignedAgent'
  #### }
  MANDATORY_ATTRS = [:property_type, :beds, :baths, :receptions, :pictures, :floorplan_url, :current_valuation, :inner_area, :outer_area]
  EDIT_ATTRS = [
                  :property_type, :beds, :baths, :receptions, :property_style, :tenure, :floors, :listed_status,
                  :year_built, :central_heating, :parking_type, :outside_space_type, :additional_features, :decorative_condition,
                  :council_tax_band, :lighting_cost, :lighting_cost_unit_type, :heating_cost, :heating_cost_unit_type,
                  :hot_water_cost, :hot_water_cost_unit_type, :annual_ground_water_cost, :annual_service_charge,
                  :resident_parking_cost, :other_costs, :total_cost_per_month, :total_cost_per_year, :improvement_types, :dream_price,
                  :current_valuation, :floorplan_url, :pictures, :expected_completion_date, :actual_completion_date, :new_owner_email_id, :vendor_address,
                  :inner_area, :outer_area, :property_brochure_url, :video_walkthrough_url, :dream_price, :asking_price, :offers_price,
                  :fixed_price, :offers_over, :area_type
                ]
  LOCALITY_ATTRS = [:postcode, :post_town, :dependent_locality, :double_dependent_locality, :dependent_thoroughfare_description,
                    :thoroughfare_description, :building_number, :building_name, :sub_building_name, :po_box_no,
                    :department_name, :organization_name, :udprn, :postcode_type, :su_organisation_indicator, :delivery_point_suffix]

  AGENT_ATTRS = [:agent_id, :assigned_agent_name, :assigned_agent_email, :assigned_agent_mobile, 
                 :assigned_agent_office_number, :assigned_agent_image_url, :assigned_agent_branch_name, 
                 :assigned_agent_branch_number, :assigned_agent_branch_address, :assigned_agent_branch_logo, 
                 :assigned_agent_branch_email, :agent_status
               ]

  VENDOR_ATTRS = [:vendor_id]

  EXTRA_ATTRS = [:property_status_type, :verification_status, :details_completed, :agent_status, :property_id,
                 :claimed_at]

  POSTCODE_ATTRS = [:area, :sector, :district, :unit, :address, :county, :vanity_url, :building_type]

  ### Additional attrs to be appended
  ADDITIONAL_ATTRS = [:status_last_updated, :sale_prices, :sale_price, :assigned_agent_first_name, :assigned_agent_last_name,
                      :assigned_agent_title, :total_area, :epc, :chain_free, :date_added, :not_yet_built, :is_new_home, :is_retirement_home, :is_shared_ownership, :description_set]

  DETAIL_ATTRS = LOCALITY_ATTRS + AGENT_ATTRS + VENDOR_ATTRS + EXTRA_ATTRS + POSTCODE_ATTRS + EDIT_ATTRS + ADDITIONAL_ATTRS

  AGENT_STATUS = {
    lead: 1,
    assigned: 2
  }

  ARRAY_HASH_ATTRS = [:outside_space_type, :additional_features, :pictures, :property_style, :sale_prices, :other_costs, :improvement_types]

  def initialize(udprn)
    @udprn = udprn
  end

  def attach_vendor_to_property(vendor_id, details={}, property_for='Sale')
    property_details = PropertyDetails.details(udprn)
    details.symbolize_keys!
    details.each {|key, value|  property_details[key] = value }
    district = property_details[:district]
    create_lead_and_update_vendor_details(district, udprn, vendor_id, property_details, property_for)
  end

  def create_lead_and_update_vendor_details(district, udprn, vendor_id, details, property_for='Sale')
    details['property_status_type'] = 'Sale' if property_for == 'Sale'
    details['property_status_type'] ||= 'Sale'
    client = Elasticsearch::Client.new host: Rails.configuration.remote_es_host
    property_status_type = Trackers::Buyer::PROPERTY_STATUS_TYPES[details['property_status_type']]
    Agents::Branches::AssignedAgents::Lead.create(district: district, property_id: udprn, vendor_id: vendor_id, property_status_type: property_status_type)
    details['property_status_type'] = nil if details['property_status_type'] == 'Sale'
    details[:vendor_id] = vendor_id
    details[:claimed_at] = Time.now.to_s
    # p details
    self.class.normalize_all_attrs(details)
    PropertyDetails.update_details(client, udprn, details)
  end

  def claim_new_property(agent_id)
    message, status = nil
    lead = Agents::Branches::AssignedAgents::Lead.where(property_id: udprn.to_i, agent_id: nil).last
    agent = Agents::Branches::AssignedAgent.find(agent_id)
    if lead && agent
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
      ### Update the agents credits
      agent.credit = agent.credit - 1
      agent.save!
    else
      message = 'Sorry, this property has already been claimed'
      status = 400
    end
    return message, status
  end

  def claim_new_property_manual(agent_id, property_for='Sale')
    message, status = nil
    details = PropertyDetails.details(udprn)
    details['property_status_type'] = 'Sale' if property_for == 'Sale'
    details['property_status_type'] ||= 'Sale'
    property_status_type = Trackers::Buyer::PROPERTY_STATUS_TYPES[details['property_status_type']]
    Agents::Branches::AssignedAgents::Lead.create!(
      district: details['district'], 
      property_id: udprn,
      agent_id: agent_id,
      vendor_id: nil, 
      property_status_type: property_status_type
    )
    message = 'You have claimed this property successfully'
    return message, 200
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
    attributes = EDIT_ATTRS + [:property_status_type]
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
    self.class.normalize_all_attrs(update_hash)
    PropertyDetails.update_details(client, udprn, update_hash) if !update_hash.empty?
    PropertyDetails.details(udprn)['_source']
  end

  def self.normalize_all_attrs(update_hash)
    update_hash.each do |each_key, value|
      if value.class.method_defined?(:to_i) && value == value.to_i.to_s
        update_hash[each_key] = value.to_i
      end
    end
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

  def self.bulk_details(udprns=[])
    details = []
    details = Rails.configuration.ardb_client.mget(*udprns) if udprns.length > 0
    results = details.map{ |detail| process_each_detail(detail) }
    results.each_with_index{ |detail, index| detail[:udprn] = udprns[index].to_i }
    results
  end

  def self.bulk_set(details_arr)
    mset_arr = []
    details_arr.each do |each_elem|
      mset_arr.push(each_elem[:udprn])
      value_str = form_value_str(each_elem)
      mset_arr.push(value_str)
    end
    Rails.configuration.ardb_client.mset(*mset_arr) if mset_arr.length > 0
  end

  def self.process_each_detail(detail_str)
    result_hash = {}
    if detail_str
      values = detail_str.split('|')
      size = 0
      prev_size = 0
      LOCALITY_ATTRS.each_with_index do |each_attr, index|
        form_value(result_hash, values, index+prev_size, each_attr)
        size += 1
      end
  
      prev_size = size
      AGENT_ATTRS.each_with_index do |each_attr, index|
        form_value(result_hash, values, index+prev_size, each_attr)
        size += 1
      end
  
      prev_size = size
      VENDOR_ATTRS.each_with_index do |each_attr, index|
        form_value(result_hash, values, index+prev_size, each_attr)
        size += 1
      end
  
      prev_size = size
      EXTRA_ATTRS.each_with_index do |each_attr, index|
        form_value(result_hash, values, index+prev_size, each_attr)
        size += 1
      end
  
      prev_size = size
      POSTCODE_ATTRS.each_with_index do |each_attr, index|
        form_value(result_hash, values, index+prev_size, each_attr)
        size += 1
      end
  
      prev_size = size
      EDIT_ATTRS.each_with_index do |each_attr, index|
        form_value(result_hash, values, index+prev_size, each_attr)
        size += 1
      end
  
      prev_size = size
      ADDITIONAL_ATTRS.each_with_index do |each_attr, index|
        form_value(result_hash, values, index+prev_size, each_attr)
        size += 1
      end
    end
    result_hash
  end

  def self.form_value(result_hash, values, index, attr_value)
    if values[index] && !values[index].empty?
      if ARRAY_HASH_ATTRS.include?(attr_value)
        result_hash[attr_value] = Oj.load(values[index]) rescue values[index]
      else
        result_hash[attr_value] = values[index]
      end
    end
  end

  def self.update_udprn(udprn, detail_hash)
    value_str = form_value_str(detail_hash)
    set_value_to_key(udprn, value_str)
  end

  def self.form_value_str(detail_hash)
    values = (1..DETAIL_ATTRS.length).map { |e| '' }
    detail_hash.each do |key, value|
      index = DETAIL_ATTRS.index(key.to_sym)
      if index
        if value && value.is_a?(Array) || value.is_a?(Hash)
          values[index] = value.to_json
        else
          values[index] = value
        end
      end
    end
    values.join('|')
  end

  def self.set_value_to_key(udprn, value_str)
    ardb_client = Rails.configuration.ardb_client
    ardb_client.set(udprn.to_s, value_str)
  end
  
  def self.update_description(udprn, description)
    ardb_client = Rails.configuration.ardb_client
    key_name = 'description_' + udprn.to_s 
    ardb_client.set(key_name, description)
  end

  def self.get_description(udprn)
    ardb_client = Rails.configuration.ardb_client
    key_name = 'description_' + udprn.to_s 
    ardb_client.get(key_name)
  end

  def self.update_full_ardb_db
    udprns = []
    count = 0
    county_map = JSON.parse(File.read("county_map.json"))
    post_towns = ["BELFAST", "HOLYWOOD", "DONAGHADEE", "NEWTOWNARDS", "BALLYNAHINCH", "DROMORE", "HILLSBOROUGH", "LISBURN", "CRUMLIN", "DOWNPATRICK", "CASTLEWELLAN", "BANBRIDGE", "NEWRY", "NEWTOWNABBEY", "CARRICKFERGUS", "BALLYCLARE", "LARNE", "ANTRIM", "BALLYMENA", "MAGHERAFELT", "MAGHERA", "LONDONDERRY", "LIMAVADY", "COLERAINE", "BALLYMONEY", "BALLYCASTLE", "PORTSTEWART", "PORTRUSH", "BUSHMILLS", "ARMAGH", "CRAIGAVON", "CALEDON", "AUGHNACLOY", "DUNGANNON", "ENNISKILLEN", "FIVEMILETOWN", "CLOGHER", "AUGHER", "OMAGH", "COOKSTOWN", "CASTLEDERG", "STRABANE"]
    counter = 0
    File.foreach('/mnt3/copy_not_yet_built.csv') do |line|
      fields = line.strip.split(',')
      udprn = fields[12].to_i
      udprns.push([udprn, fields[10], fields[11], fields[6], fields[7], fields[8], fields[4], fields[5], fields[0], fields[1], fields[2], fields[-3], fields[-2], fields[-1]])
      details_arr = []
      if udprns.length == 1
        list_udprns = udprns.map{|t| t[0] }
        arr_details = PropertyService.bulk_details(list_udprns)
        arr_details.each_with_index do |details, index|
          if details && !details.empty?
            county = udprns[index][-1]
            post_town = udprns[index][-2]
            dependent_locality = udprns[index][-3]
            original_dependent_locality = udprns[index][-4]
            original_post_town = udprns[index][-5]
            original_county = county_map[original_post_town.upcase]
            post_town.empty? ? post_town = original_post_town : post_town = post_town
            dependent_locality.empty? ? dependent_locality = original_dependent_locality : dependent_locality = dependent_locality
            county.empty? ? county = original_county : county = county
            post_town = post_town.split(' ').map{|t| t.capitalize}.join(' ')
            details[:county] = county
            details[:post_town] = post_town
            details[:dependent_locality] = dependent_locality
            details[:double_dependent_locality] = nil
            details[:postcode] = udprns[index][-6]
            details[:dependent_thoroughfare_description] = udprns[index][-7]
            details[:thoroughfare_description] = udprns[index][-8]
            details[:organization_name] = udprns[index][-12]
            details[:department_name] = udprns[index][-13]
            details[:sub_building_name] = udprns[index][-9]
            details[:building_name] = udprns[index][-10]
            details[:building_number] = udprns[index][-11]
            details[:district] = details[:postcode].split(' ')[0]
            details[:sector] = details[:district]+ ' ' + details[:postcode].split(' ')[1].match(/([0-9]+)[A-Z]+/)[1]
            details[:unit] = details[:postcode]
            details[:area] = details[:district].match(/([A-Z]+)[0-9]+/)[1]
            details[:vanity_url] = nil
            details[:address] = nil
            details[:udprn] = udprns[index][0]
            details[:not_yet_built] = true
            details_arr.push(details)
          end
        end
        PropertyService.bulk_set(details_arr)
        details_arr = []
        udprns = []
      end
        details_arr = []
        list_udprns = udprns.map{|t| t[0] }
        arr_details = PropertyService.bulk_details(list_udprns)
        arr_details.each_with_index do |details, index|
          if details && !details.empty?
            county = udprns[index][-1]
            post_town = udprns[index][-2]
            dependent_locality = udprns[index][-3]
            original_dependent_locality = udprns[index][-4]
            original_post_town = udprns[index][-5]
            original_county = county_map[original_post_town.upcase]
            post_town.empty? ? post_town = original_post_town : post_town = post_town
            dependent_locality.empty? ? dependent_locality = original_dependent_locality : dependent_locality = dependent_locality
            county.empty? ? county = original_county : county = county
            post_town = post_town.split(' ').map{|t| t.capitalize}.join(' ')
            details[:county] = county
            details[:post_town] = post_town
            details[:dependent_locality] = dependent_locality
            details[:double_dependent_locality] = nil
            details[:postcode] = udprns[index][-6]
            details[:dependent_thoroughfare_description] = udprns[index][-7]
            details[:thoroughfare_description] = udprns[index][-8]
            details[:organization_name] = udprns[index][-12]
            details[:department_name] = udprns[index][-13]
            details[:sub_building_name] = udprns[index][-9]
            details[:building_name] = udprns[index][-10]
            details[:building_number] = udprns[index][-11]
            details[:district] = details[:postcode].split(' ')[0]
            details[:sector] = details[:district]+ ' ' + details[:postcode].split(' ')[1].match(/([0-9]+)[A-Z]+/)[1]
            details[:unit] = details[:postcode]
            details[:area] = details[:district].match(/([A-Z]+)[0-9]+/)[1]
            details[:vanity_url] = nil
            details[:address] = nil
            details[:udprn] = udprns[index][0]
            details[:not_yet_built] = true
            details_arr.push(details)
          end
        end
      PropertyService.bulk_set(details_arr)
      p "#{count/10000}" if count % 10000 == 0
      count += 1
    end
    nil
  end

  def self.update_last_sale_prices
    ardb_client = Rails.configuration.ardb_client
    count = 0
    udprns = []
    arr_details = nil
    File.foreach('/mnt3/udprn_last_transactions.csv') do |line|
      fields = line.split(',')
      date = fields[2].split(' ')[0]
      price = fields[1]
      udprn = fields[3]
      udprns.push([udprn, date, price] )
      if udprns.length == 400
        list_udprns = udprns.map{|t| t[0] }
        arr_details = PropertyService.bulk_details(list_udprns)
        details_arr = []
        arr_details.each_with_index do |details, index|
          details[:sale_prices] ||= []
          details[:sale_prices].push({price: udprns[index][2], date: udprns[index][1]})
          details_arr.push(details)
        end
        PropertyService.bulk_set(details_arr)
        udprns = []
      end
      count += 1
      p "#{count/10000}" if count % 10000 == 0
    end
    list_udprns = udprns.map{|t| t[0] }
    arr_details = PropertyService.bulk_details(list_udprns)
    details_arr = []
    arr_details.each_with_index do |details, index|
      details[:sale_prices] ||= []
      details[:sale_prices].push({price: udprns[index][2], date: udprns[index][1]})
      details_arr.push(details)
    end
    PropertyService.bulk_set(details_arr)
  end

end

