class PropertyService

  attr_accessor :udprn, :sold_property, :created_lead

  #### AGENT_STATUS_MAP
  #### {
  ####    1 => 'Lead',
  ####    2 => 'AssignedAgent'
  #### }
  MANDATORY_ATTRS = [ :property_type, :beds, :baths, :receptions, :pictures, :current_valuation,  :additional_features,
                      :description_set, :property_style, :tenure, :floors, :listed_status, :year_built, :parking_type, :outside_space_types, :decorative_condition,
                      :council_tax_band, :council_tax_band_cost, :council_tax_band_cost_unit, :lighting_cost, :lighting_cost_unit, :heating_cost,
                      :heating_cost_unit, :hot_water_cost, :hot_water_cost_unit, :annual_service_charge, :ground_rent_cost, :ground_rent_unit,
                      :latitude, :longitude, :assigned_agent_branch_logo, :assigned_agent_image_url, :assigned_agent_branch_name, :assigned_agent_branch_address,
                      :assigned_agent_branch_website ]

  EDIT_ATTRS = [
                  :property_type, :beds, :baths, :receptions, :property_style, :tenure, :floors, :listed_status,
                  :year_built, :central_heating, :parking_type, :outside_space_type, :additional_features, :decorative_condition,
                  :council_tax_band, :lighting_cost, :lighting_cost_unit, :heating_cost, :heating_cost_unit,
                  :hot_water_cost, :hot_water_cost_unit, :annual_ground_water_cost, :annual_service_charge,
                  :resident_parking_cost, :other_costs, :total_cost_per_month, :total_cost_per_year, :improvement_types, :dream_price,
                  :current_valuation, :floorplan_url, :pictures, :expected_completion_date, :actual_completion_date, :new_owner_email_id, :vendor_address,
                  :inner_area, :outer_area, :property_brochure_url, :video_walkthrough_url, :dream_price, :asking_price, :offers_price,
                  :fixed_price, :offers_over, :area_type
                ]

  LOCALITY_ATTRS = [
                    :postcode, :post_town, :dependent_locality, :double_dependent_locality, :dependent_thoroughfare_description,
                    :thoroughfare_description, :building_number, :building_name, :sub_building_name, :po_box_no,
                    :department_name, :organization_name, :udprn, :postcode_type, :su_organisation_indicator, :delivery_point_suffix
                   ]

  AGENT_ATTRS = [
                 :agent_id, :assigned_agent_name, :assigned_agent_email, :assigned_agent_mobile, 
                 :assigned_agent_office_number, :assigned_agent_image_url, :assigned_agent_branch_name, 
                 :assigned_agent_branch_number, :assigned_agent_branch_address, :assigned_agent_branch_logo, 
                 :assigned_agent_branch_email, :agent_status
                ]

  VENDOR_ATTRS = [:vendor_id]

  EXTRA_ATTRS = [:property_status_type, :verification_status, :details_completed, :agent_status, :property_id,
                 :claimed_on]

  POSTCODE_ATTRS = [:area, :sector, :district, :unit, :address, :county, :vanity_url, :building_type]

  ### Additional attrs to be appended
  ADDITIONAL_ATTRS = [:status_last_updated, :sale_prices, :sale_price, :assigned_agent_first_name, :assigned_agent_last_name,
                      :assigned_agent_title, :total_area, :epc, :chain_free, :date_added, :not_yet_built, :is_new_home, :is_retirement_home, :is_shared_ownership, 
                      :description_set, :claimed_by, :listing_category, :price_qualifier, :price, :vendor_first_name, :vendor_last_name,
                      :vendor_email, :vendor_image_url, :vendor_mobile_number, :description_snapshot, :street_view_image_url, :last_sale_price,
                      :is_developer, :floorplan_urls, :latitude, :longitude, :renter_id, :council_tax_band_cost, :council_tax_band_cost_unit,
                      :resident_parking_cost_unit, :outside_space_types, :ground_rent_cost, :ground_rent_type, :sale_price_type, :percent_completed, 
                      :lettings, :rent_available_from, :rent_available_to, :rent_price, :rent_price_type, :rent_furnishing_type, :student_accommodation,
                      :assigned_agent_branch_website, :ground_rent_unit, :property_status_last_updated, :floorplan_hidden, :ads]

  COUNTIES = ["Aberdeenshire", "Kincardineshire", "Lincolnshire", "Banffshire", "Hertfordshire", "West Midlands", "Warwickshire", "Worcestershire", "Staffordshire", "Avon", "Somerset", "Wiltshire", "Lancashire", "West Yorkshire", "North Yorkshire", "ZZZZ", "Dorset", "Hampshire", "East Sussex", "West Sussex", "Kent", "County Antrim", "County Down", "Gwynedd", "County Londonderry", "County Armagh", "County Tyrone", "County Fermanagh", "Cumbria", "Cambridgeshire", "Suffolk", "Essex", "South Glamorgan", "Mid Glamorgan", "Cheshire", "Clwyd", "Merseyside", "Surrey", "Angus", "Fife", "Derbyshire", "Dumfriesshire", "Kirkcudbrightshire", "Wigtownshire", "County Durham", "Tyne and Wear", "South Yorkshire", "North Humberside", "South Humberside", "Nottinghamshire", "Midlothian", "West Lothian", "East Lothian", "Peeblesshire", "Middlesex", "Devon", "Cornwall", "Stirlingshire", "Clackmannanshire", "Perthshire", "Lanarkshire", "Dunbartonshire", "Gloucestershire", "Berkshire", "not", "Buckinghamshire", "Herefordshire", "Isle of Lewis", "Isle of Harris", "Isle of Scalpay", "Isle of North Uist", "Isle of Benbecula", "Inverness-shire", "Isle of Barra", "Norfolk", "Ross-shire", "Nairnshire", "Sutherland", "Morayshire", "Isle of Skye", "Ayrshire", "Isle of Arran", "Isle of Cumbrae", "Caithness", "Orkney", "Kinross-shire", "Powys", "Leicestershire", "Leicestershire / ", "Leicestershire / Rutland", "Dyfed", "Bedfordshire", "Northumberland", "Northamptonshire", "Gwent", "Shropshire", "Oxfordshire", "Renfrewshire", "Isle of Bute", "Argyll", "Isle of Gigha", "Isle of Islay", "Isle of Jura", "Isle of Colonsay", "Isle of Mull", "Isle of Iona", "Isle of Tiree", "Isle of Coll", "Isle of Eigg", "Isle of Rum", "Isle of Canna", "Isle of Wight", "West Glamorgan", "Selkirkshire", "Berwickshire", "Roxburghshire", "Isles of Scilly", "Cleveland", "Shetland Islands", "Central London", "East London", "North West London", "North London", "South East London", "South West London","Dummy", "West London"] 
       
  DETAIL_ATTRS = LOCALITY_ATTRS + AGENT_ATTRS + VENDOR_ATTRS + EXTRA_ATTRS + POSTCODE_ATTRS + EDIT_ATTRS + ADDITIONAL_ATTRS

  ADDITIONAL_EDIT_ATTRS = [ :property_status_type, :description, :agent_id, :council_tax_band_cost, :council_tax_band_cost_unit,
                            :annual_ground_water_cost_unit, :resident_parking_cost_unit, :outside_space_types, :lettings,
                            :rent_available_from, :rent_available_to, :rent_price, :rent_price_type, :rent_furnishing_type,
                            :student_accommodation, :ground_rent_unit, :sale_price, :sale_price_type, :is_new_home, :is_retirement_home,
                            :is_shared_ownership, :chain_free, :property_status_last_updated, :floorplan_hidden ]

  AGENT_STATUS = {
    lead: 1,
    assigned: 2
  }

  INT_ATTRS = [ :council_tax_band_cost, :ground_rent_cost, :annual_ground_water_cost, :annual_service_charge, :lighting_cost, :heating_cost, :hot_water_cost, :resident_parking_cost, :rent_price ]

  BOOL_ATTRS = [ :lettings, :student_accommodation ]

  ARRAY_HASH_ATTRS = [:outside_space_type, :additional_features, :pictures, :sale_prices, :other_costs, :improvement_types, :floorplan_urls, :outside_space_types]

  BUYER_MATCH_ATTRS = [:beds, :baths, :receptions, :property_status_type, :property_type ]

  LAND_REGISTRY_ATTRS = [ :property_type, :tenure, :sale_prices, :last_sale_price ]

  NON_ZERO_INT_FLOAT_ATTRS = [:last_sale_price, :inner_area ] + INT_ATTRS

  BASE_ATTRS = LOCALITY_ATTRS + POSTCODE_ATTRS + LAND_REGISTRY_ATTRS

  STATUS_MANDATORY_ATTRS_MAP = {
    'Green' => MANDATORY_ATTRS + [:sale_price, :sale_price_type],
    'Amber' => MANDATORY_ATTRS,
    'Red'   => MANDATORY_ATTRS
  }

  def initialize(udprn)
    @udprn = udprn
  end

  def self.service(details)
   if details[:property_status_type] != 'Rent'
     'Sale'
   else
     details[:property_status_type]
   end
  end

  def self.get_results_from_es_suggest(query_str, size=10)
    query_str = {
      postcode_suggest: {
        text: query_str,
        completion: {
          field: 'suggest',
          size: size
        }
      }
    }
    res, code = post_url(Rails.configuration.location_index_name, nil, '_suggest' , query_str)
  end


  def self.get_results_from_es_suggest_new_build(query_str, size=10)
    query_str = {
      postcode_suggest: {
        text: query_str,
        completion: {
          field: 'suggest',
          size: size
        }
      }
    }
    res, code = post_url(Rails.configuration.new_property_locations_index_name, nil, '_suggest' , query_str)
  end

  def self.attach_vendor_details(vendor_id, update_hash={})
    vendor = Vendor.where(id: vendor_id).last
    if vendor
      update_hash[:vendor_first_name] = vendor.first_name
      update_hash[:vendor_last_name] = vendor.last_name
      update_hash[:vendor_image_url] = vendor.image_url
      update_hash[:vendor_email] = vendor.email
      update_hash[:vendor_mobile_number] = vendor.mobile
    else
      update_hash[:vendor_first_name] = nil  
      update_hash[:vendor_last_name] = nil  
      update_hash[:vendor_image_url] = nil
      update_hash[:vendor_email] = nil
      update_hash[:vendor_mobile_number] = nil
    end
  end

  def compute_percent_completed(update_hash={}, details_hash={})
    details_hash = PropertyDetails.details(@udprn)[:_source] if details_hash.empty?

    ### Check if mandatory attrs completed since only agent and vendor attrs are populated after this
    update_hash[:details_completed] = false
    property_status_type = details_hash[:property_status_type] || update_hash[:property_status_type]
    property_status_type ||= 'Red'
    mandatory_attrs = nil

    mandatory_attrs = PropertyService::STATUS_MANDATORY_ATTRS_MAP[property_status_type] + [:address] if property_status_type
    mandatory_attrs ||= PropertyService::STATUS_MANDATORY_ATTRS_MAP['Red'] + [:address]

    ### Populate details completed and percent of attributes completed
    details_completed = mandatory_attrs.all?{ |attr| details_hash.has_key?(attr) && !details_hash[attr].blank? }
    update_hash[:details_completed] = true if details_completed
    total_mandatory_attrs = mandatory_attrs.select{ |t| !t.to_s.end_with?('_unit') }
    attrs_completed = mandatory_attrs.select{ |attr| details_hash.has_key?(attr) && !details_hash[attr].blank? }.count
    ((attrs_completed.to_f/mandatory_attrs.length.to_f)*100.0).round(2)
  end

  def attach_vendor_to_property(vendor_id, details={}, property_for='Sale')
    property_details = PropertyDetails.details(udprn)[:_source]
    district = property_details[:district]

    ### Attach address district register id
    pre_agent_id = source = nil
    addr_dist_reg = AddressDistrictRegister.where(udprn: udprn, expired: false).last
    if addr_dist_reg
      source = Agents::Branches::AssignedAgents::Lead::SOURCE_MAP[:mailshot]
      pre_agent_id = addr_dist_reg.agent_id
    end

    create_lead_and_update_vendor_details(district, udprn, vendor_id, property_details, property_for, source, pre_agent_id)
  end

  def create_lead_and_update_vendor_details(district, udprn, vendor_id, details, property_for='Sale', source=nil, pre_agent_id=nil)
    create_lead_for_local_branches(district, udprn, vendor_id, source, pre_agent_id)
    update_hash = { vendor_id: vendor_id, claimed_on: Time.now.to_s, claimed_by: 'Vendor' }
    Rails.logger.info("CREATE_LEAD_UPDATE_HASH_#{update_hash}")
    PropertyService.new(udprn.to_i).update_details(update_hash)
  end

  def create_lead_for_local_branches(district, property_id, vendor_id, source=nil, pre_agent_id=nil)
    lead = Agents::Branches::AssignedAgents::Lead.create(district: district, property_id: udprn, vendor_id: vendor_id, source: source, pre_agent_id: pre_agent_id)
    @created_lead ||= lead
    AgentVendorLeadNotifyWorker.perform_async(property_id)
  end

  def claim_new_property(agent_id)
    message, status = nil
    lead = Agents::Branches::AssignedAgents::Lead.where(property_id: udprn.to_i, agent_id: nil).last
    agent = Agents::Branches::AssignedAgent.find(agent_id)
    Rails.logger.info("PropertyService_CLAIM_NEW_PROPERTY__#{agent}__#{lead}_#{agent_id}")
    if lead && agent
      lead.agent_id = agent_id
      lead.claimed_at = Time.now
      lead.save!

      @created_lead ||= lead
      
      Rails.logger.info("CREATED_LEAD_#{@created_lead}")

      update_hash = { agent_id: agent_id, agent_status: 1 }
      details, status = PropertyService.new(udprn).update_details(update_hash)
      vendor_id = lead.vendor_id
      vendor_details = Vendor.where(id: vendor_id).select([:first_name, :last_name, :email, :image_url, :mobile]).last
      deadline = lead.claimed_at + Agents::Branches::AssignedAgents::Lead::VERIFICATION_DAY_LIMIT
      message = { message: 'You have claimed this property successfully. Now survey this property within 7 days', vendor_details: vendor_details, deadline: deadline }
      address = nil
      VendorService.new(vendor_id).send_email_following_agent_lead(agent_id, address)
      status = 200
      ### Update the agents credits
      Rails.logger.info("PROPERTY_CLAIM_#{agent.id}_#{udprn.to_i}  with credit #{agent.credit} and email #{agent.email}")

      ### If lead is not preempted
      if lead.pre_agent_id.nil?
        agent.credit = agent.credit - Agents::Branches::AssignedAgent::PER_LEAD_COST ### Deduct 10 credits for claiming a lead
      end

      agent.save!
    else
      message = 'Sorry, this property has already been claimed'
      status = 400
    end
    return message, status
  end

  def claim_new_property_manual(agent_id, owned_property=true)
    message, status = nil
    details = PropertyDetails.details(udprn)[:_source]
    Agents::Branches::AssignedAgents::Lead.create!(
      district: details[:district], 
      property_id: udprn,
      agent_id: agent_id,
      owned_property: owned_property,
      vendor_id: nil
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

    attributes = (EDIT_ATTRS + MANDATORY_ATTRS + ADDITIONAL_EDIT_ATTRS).uniq

    ### Assume that details have been completed and are validated.
    ### TODO: Fix validations and delay assigning the attribute till validations are
    ### complete.

    ### Send the report to the vendor if the agent has submitted the attributes after winning the lead
		attributes.each do |attribute|
      update_hash[attribute] = details[attribute] if details.has_key?(attribute)
    end
    ### Update pictures only when it is in the correct format
    pictures = update_hash[:pictures]
    if pictures.is_a?(Array) && pictures.all?{ |t| t.has_key?('url') }
      update_hash[:pictures] = pictures
    else
      update_hash.delete(:pictures) if update_hash[:pictures] ### Disallow pictures to be updated if they're not valid
    end

    vendor_id = details[:vendor_id]
    agent_id = details[:agent_id]
    cond = !vendor_id.nil? && !agent_id.nil? && details[:agent_status] == AGENT_STATUS[:lead] && details_completed
    VendorService.new(vendor_id).send_email_following_agent_details_submission(agent_id, details) if cond
    self.class.normalize_all_attrs(update_hash)
    update_details(update_hash) if !update_hash.empty?
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
    populate_agent_details(agent, details)
    #details['details_completed'] = true
    details[:is_developer] = agent.is_developer
    details['agent_status'] = AGENT_STATUS[:assigned]
    PropertyDetails.update_details(client, udprn, details)
  end

  def populate_agent_details(agent, details)
		details['assigned_agent_first_name'] = agent.first_name
		details['assigned_agent_last_name'] = agent.last_name
    details['assigned_agent_email'] = agent.email
    details['assigned_agent_mobile'] = agent.mobile
    details['assigned_agent_office_number'] = agent.office_phone_number
    details['assigned_agent_image_url'] = agent.image_url
    branch = agent.branch
    details['assigned_agent_branch_name'] = branch.name
		details['assigned_agent_branch_number'] = branch.phone_number
    details['assigned_agent_branch_address'] = branch.address
    details['assigned_agent_branch_website'] = branch.website
    details['assigned_agent_branch_logo'] = branch.image_url
  end
  
  def is_property_is_in_lead_stage?(details)
  end

  def details
    PropertyDetails.details(@udprn.to_i)[:_source]
  end

  def self.post_url(index_name, type_name, endpoint='_search', query={})
    es_url = Rails.configuration.remote_es_url
    uri = URI.parse(URI.encode("#{es_url}/#{index_name}/#{endpoint}"))
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
    results = results.each{ |t| t[:verification_status] = (t[:details_completed].to_s == "true"); t[:floorplan_url] = t[:floorplan_urls] = nil if t[:floorplan_hidden].to_s == 'true';   t[:address] = PropertyDetails.address(t); t[:vanity_url] = PropertyDetails.vanity_url(t[:address]) }
    results
  end

  def self.details_with_only_locality_attrs(udprns=[])
    details = []
    details = Rails.configuration.ardb_client.mget(*udprns) if udprns.length > 0
    results = details.map{ |detail| process_locality_attr(detail) }
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

  def self.process_locality_attr(detail_str)
    result_hash = {}
    if detail_str
      values = detail_str.split('|')
      size = 0
      prev_size = 0
      LOCALITY_ATTRS.each_with_index do |each_attr, index|
        form_value(result_hash, values, index+prev_size, each_attr)
        size += 1
      end

      POSTCODE_ATTRS.each_with_index do |each_attr, index|
        form_value(result_hash, values, index+prev_size, each_attr)
        size += 1
      end
    end
    result_hash
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
      elsif (NON_ZERO_INT_FLOAT_ATTRS.include?(attr_value)) && values[index].to_i == 0
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
        elsif (NON_ZERO_INT_FLOAT_ATTRS.include?(key)) && value.to_i == 0
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

  def self.fetch_details_from_vanity_url(url, user=nil)
    url = url.gsub(/[_]/,"/")
    str_parts = url.split('-')[0..-3]
    str_parts = str_parts.map {|t| t.gsub("|","") }
    str = ''
    last_occurence = str_parts.reverse.find_all{|t| str=t+' '+ str;COUNTIES.include?(str.titleize.strip)}.last
    county_index = str_parts.index(last_occurence)
    prediction_str = str_parts[0..county_index-1].join(' ')
    results, code = PropertyService.get_results_from_es_suggest(prediction_str, 1)
    udprn = Oj.load(results)['postcode_suggest'][0]['options'][0]['text'].split('_')[0]
    details = PropertyDetails.details(udprn.to_i)[:_source]
    details[:percent_completed] = PropertyService.new(udprn.to_i).compute_percent_completed({}, details)
    if true
      photo_urls = Api::V0::PropertySearchController.helpers.process_image(details)
      !photo_urls.is_a?(Array) ? details['photo_urls'] = [ photo_urls ] : details['photo_urls'] = photo_urls
      details[:description] = get_description(udprn)
    else
      details.keys.each do |each_key|
        details.delete(each_key) if !(LOCALITY_ATTRS.include?(each_key) || POSTCODE_ATTRS.include?(each_key))
      end
    end
    details
  end

  def calculate_pricing_history
    valuation_history = PropertyEvent.where(udprn: @udprn).where("attr_hash ? 'current_valuation'").order('current_valuation desc')
                                     .select([:created_at]).select("attr_hash ->> 'current_valuation' as current_valuation ")
    dream_price_history = PropertyEvent.where(udprn: @udprn).where("attr_hash ? 'dream_price'").order('dream_price desc')
                                       .select([:created_at]).select("attr_hash ->> 'dream_price' as dream_price ")
   # sold_price_history = SoldProperty.where(udprn: @udprn).select([:sale_price, 'completion_date as created_at']).order('created_at DESC').to_a
    last_sale_prices = PropertyService.new(@udprn.to_i).details[:sale_prices]
    last_sale_prices ||= []
    last_sale_prices = last_sale_prices.each { |t| t[:time] = t[:date] + 'T00:00:00Z' }
    last_sale_prices = last_sale_prices.sort_by{|t| Time.parse(t['date'] + 'T00:00:00Z')}
#    sold_price_history = SoldProperty.where(udprn: @udprn).select([:sale_price, 'completion_date as created_at']).order('created_at DESC').to_a

    sale_price_history = PropertyEvent.where(udprn: @udprn).where("(attr_hash ? 'price') OR (attr_hash ? 'sale_price')").order('sale_price DESC')
                                      .select([:created_at])
                                      .select("CASE WHEN (attr_hash ? 'price') THEN attr_hash ->> 'price'  ELSE  attr_hash ->> 'sale_price' END as sale_price")
    {
      valuation_history: valuation_history,
      dream_price_history: dream_price_history,
      sold_price_history: last_sale_prices,
      sale_price_history: sale_price_history
    }
  end

  def attach_crawled_property_attrs_to_udprn
    Agents::Branches::CrawledProperty.where("udprn = #{@udprn.to_i}").each do |crawled_property_detail|
      details = PropertyDetails.details(@udprn)[:_source]
      details[:listing_category] = crawled_property_detail.additional_details['listings_category'] 
      details[:price] = crawled_property_detail.additional_details['price'] 
      details[:tenure] = crawled_property_detail.additional_details['tenure'] 
      details[:assigned_agent_branch_name] = crawled_property_detail.additional_details['branch_name'] 
      details[:assigned_agent_branch_logo] = crawled_property_detail.stored_response['agent_logo'] 
      details[:property_type] = crawled_property_detail.additional_details['property_type'] 
      details[:epc] = crawled_property_detail.additional_details['has_epc'] 
      details[:floorplan_url] = crawled_property_detail.stored_response['floorplan_url']

      details[:total_area] = crawled_property_detail.additional_details['size_sq_feet']
      ### If size_sq_metres exists and total_area is unknown
      if details[:total_area].nil? && crawled_property_detail.additional_details['size_sq_metres']
        details[:total_area] = (crawled_property_detail.additional_details['size_sq_metres'].to_f*3.280).to_i
      end
      details[:price_qualifier] = crawled_property_detail.additional_details['price_qualifier']
      details[:property_style] = crawled_property_detail.additional_details['listing_condition']
      details[:is_retirement_home] = crawled_property_detail.additional_details['is_retirement_home']
      highlights = crawled_property_detail.additional_details['property_highlights'].split('|') rescue []

      ### Update branch's opening hours
      branch = crawled_property_detail.branch
      branch.opening_hours = crawled_property_detail.additional_details['opening_hours'] if branch.opening_hours.nil?
      branch.image_url = details['assigned_agent_branch_logo'] if branch.image_url.nil?
      branch.save!

      ### From stored response
      details[:beds] = crawled_property_detail.stored_response['beds']
      details[:baths] = crawled_property_detail.stored_response['baths']
      details[:receptions] = crawled_property_detail.stored_response['receptions']

      ### Take features from highlghts as well
      main_features = crawled_property_detail.stored_response['features']
      main_features ||= []
      details[:additional_features] = main_features + highlights
      details[:description] = crawled_property_detail.stored_response['description']

      update_details(details)
    end
  end

  def update_details(update_hash)
    client = Elasticsearch::Client.new host: Rails.configuration.remote_es_host
    PropertyDetails.update_details(client, @udprn, update_hash)
  end

  def self.send_tracking_email_to_tracking_buyers(update_hash, property_details)
    property_status_type_changed = (update_hash[:property_status_type] != property_details[:property_status_type])
    TrackingEmailWorker.new.perform(update_hash, property_details) if property_status_type_changed
  end

  def self.update_full_ardb_db
    udprns = []
    client = Elasticsearch::Client.new host: Rails.configuration.remote_es_host
    count = 0
    county_map = JSON.parse(File.read("county_map.json"))
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

  def self.update_last_sale_price
    ardb_client = Rails.configuration.ardb_client
    udprns = []
    count = 0
    details_arr = []
    File.foreach('/mnt3/royal.csv') do |line|
      #if (count/10000) > 1146
        processed_line = line.strip.encode('UTF-8', :invalid => :replace)
        udprn = processed_line.split(',')[12]
        udprns.push(udprn)
        if udprns.length == 800
          arr_details = PropertyService.bulk_details(udprns)
          arr_details.each_with_index do |details, index|
            DETAIL_ATTRS - BASE_ATTRS.each{|t| details[t] = nil }
            details_arr.push(details)
#            details[:price] = details[:sale_price]
#            if details[:sale_prices]
#              #details[:last_sale_price] = details[:sale_prices].sort_by{ |t| Date.parse(t['date']) }.last['price']
#              details[:sale_prices] = details[:sale_prices].compact.uniq{ |t| Date.parse(t['date']) }
#              details_arr.push(details)
#            end
            details_arr.push(details)
          end
          udprns = []
          PropertyService.bulk_set(details_arr)
          details_arr = []
        end
      #end
      count += 1
      p "#{count/10000}" if count % 10000 == 0
    end
  end

  def self.update_last_sale_prices
    ardb_client = Rails.configuration.ardb_client
    count = 0
    udprns = []
    arr_details = nil
    # {61D8894E-B7CD-3DE6-E053-6C04A8C01207}|26528855|2017-10-27|117000|O|L
    property_type_map = {
      'D' => 'detached',
      'T' => 'terraced',
      'S' => 'semi_detached',
      'F' => 'flat' 
    }
    tenure_map = {
      'L' => 'Leasehold',
      'F' => 'Freehold'
    }
    size = 600
    File.foreach('/mnt3/lspm.csv') do |line|
      fields = line.scrub.strip.split('|')
      date = fields[2]
      price = fields[3].to_i
      udprn = fields[1].to_i
      property_type = property_type_map[fields[4]]
      tenure = tenure_map[fields[5]]
      udprns.push([udprn, date, price, property_type, tenure] )
      if udprns.length == size
        list_udprns = udprns.map{|t| t[0] }
        arr_details = PropertyService.bulk_details(list_udprns)
        details_arr = []
        arr_details.each_with_index do |details, index|
          details[:price] = details[:sale_price]
          details[:sale_prices] ||= []
          details[:sale_prices].push({'price'=> udprns[index][2], 'date'=> udprns[index][1]})
          details[:sale_prices] = details[:sale_prices].uniq{|t| t['date'] }
          details[:property_type] = udprns[index][3]
          details[:tenure] = udprns[index][4]
          DETAIL_ATTRS - BASE_ATTRS.each{|t| details[t] = nil }
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
      details[:price] = details[:sale_price]
      details[:sale_prices] ||= []
      details[:sale_prices].push({'price'=> udprns[index][2], 'date'=> udprns[index][1]})
      details[:sale_prices] = details[:sale_prices].uniq{|t| t['date'] }
      details[:property_type] = udprns[index][3]
      details[:tenure] = udprns[index][4]
      DETAIL_ATTRS - BASE_ATTRS.each{|t| details[t] = nil }
      details_arr.push(details)
    end
    PropertyService.bulk_set(details_arr)
  end

end

