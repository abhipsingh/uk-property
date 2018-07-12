require 'base64'
class PropertyDetails

  attr_reader :attributes

  TRACKING_ATTRS = [ :agent_id, :vendor_id, :property_status_type, :current_valuation, :price, :dream_price, :beds, :baths, :receptions ]

  def initialize(attributes={})
    @attributes = attributes
  end

  def to_hash
    @attributes
  end

  def self.address(details)
    details = details.with_indifferent_access
    units = [:organization_name, :department_name, :sub_building_name, :building_name, :building_number, :dependent_thoroughfare_description, 
             :thoroughfare_description, :dependent_locality, :post_town, :county, :postcode ]
    units.select { |t| details[t] && !details[t].blank? }.map{|t| details[t] }.join(', ')
  end

  def self.google_st_view_address(details)
    published_address = ''
    address_fields = [:building_number, :dependent_thoroughfare_description, :thoroughfare_description,
                      :double_dependent_locality, :dependent_locality, :post_town, :postcode]
    address_fields.select{ |t| details[t] }.map{|t| details[t] }.join(', ')
  end

  def self.fr_google_st_view_address(details)
    published_address = ''
    address_fields = [:building_name, :dependent_thoroughfare_description, :dependent_locality, :postcode]
    building_name = details[:building_name].split(",")[0]
    hash = details.deep_dup
    hash[:building_name] = building_name
    address_fields.select{ |t| hash[t] }.map{|t| hash[t] }.join(', ')
  end

  def self.street_address(details)
    address_parts = [:dependent_thoroughfare_description, :thoroughfare_description, :dependent_locality, :post_town, :county, :postcode].map do |t|
      details[t]
    end
    address_parts.compact.join(', ')
  end

  def self.get_signed_url(udprn)
    s3 = Aws::S3::Resource.new
    object = s3.bucket('propertyuk').object("#{udprn}_street_view.jpg")
    object.presigned_url(:get, expires_in: 300)
  end

  def self.get_map_view_iframe_url(details)
    location_address = address(details)
    get_iframe_url_for_address(location_address)
  end

  def self.get_iframe_url_for_address(address)
    "https://www.google.com/maps/embed/v1/place?key=#{ENV['GOOGLE_API_BROWSER_KEY']}&q=#{address}"
  end

  def self.details(udprn)
    details = PropertyService.bulk_details([udprn]).first
    details[:address] = address(details)
    details[:vanity_url] = vanity_url(details[:address])
    details[:udprn] = udprn
    details[:latitude] = details[:latitude].to_f
    details[:longitude] = details[:longitude].to_f
    details[:percent_completed] = PropertyService.new(udprn).compute_percent_completed({}, details)
    details[:verification_status] = (details[:percent_completed].to_i == 100)
    PropertyService::INT_ATTRS.each { |t| details[t] = details[t].to_i if details[t] }
    PropertyService::BOOL_ATTRS.each { |t| details[t] = (details[t].to_s == 'true') if details[t] }
    { '_source' => details }.with_indifferent_access
  end

  def self.vanity_url(address)
    address = address.gsub(/[\/]/,"_").gsub(".","")
    address = address.gsub("-","|")
    address.split(',').map{|t| t.strip.split(' ').map{|k| k.downcase}.join('-') }.join('-')
  end

  ### Always returns the udprns of the properties which have the same beds, baths, receptions,
  ### and the same sector as the udprn.
  def self.similar_properties(udprn)
    property_details = details(udprn)['_source']
    search_params = {
      min_beds: property_details['beds'].to_i,
      max_beds: property_details['beds'].to_i,
      min_baths: property_details['baths'].to_i,
      max_baths: property_details['baths'].to_i,
      min_receptions: property_details['receptions'].to_i,
      max_receptions: property_details['receptions'].to_i,
      property_types: property_details['property_type'].to_s,
      sector: property_details['sector'].to_s,
      fields: 'udprn'
    }
    Rails.logger.info(search_params)
    api = PropertySearchApi.new(filtered_params: search_params)
    api.apply_filters
    body, status = api.fetch_data_from_es
    udprns = []
    if status.to_i == 200
      udprns = body.map { |e| e['udprn'] }
    end
    udprns
  end

  def self.get_potential_matches_for_tracking(property_details, hash_str, receptions, beds, baths, property_type)
    locality_hashes = property_details['hashes'].find{ |hashes| hashes.end_with? hash_str.to_s }
    params = {
      hash_str: locality_hashes,
      hash_type: 'text',
      type_of_match: 'potential',
      min_receptions: receptions,
      min_beds: beds,
      min_baths: baths,
      max_receptions: receptions,
      max_beds: beds,
      max_baths: baths,
      property_types: property_type,
      listing_type: 'Premium'
    }
    api = ::PropertySearchApi.new(filtered_params: params)
    result, _ = api.filter
    result.count
  end

  def self.historic_pricing_details(udprn)
    VendorApi.new(udprn.to_s).calculate_valuations
  end

  def self.send_email_to_trackers(udprn, update_hash, last_property_status_type, property_details)
    if property_details.present?
      address = property_details["address"]

      street = property_details["dependent_thoroughfare_description"]
      locality = property_details["dependent_locality"]

      receptions = property_details["receptions"]
      baths = property_details["baths"]
      beds = property_details["beds"]
      property_type = property_details["property_type"]
      @street_potential_matches = PropertyDetails.get_potential_matches_for_tracking(property_details, street, receptions, beds, baths, property_type)
      @locality_potential_matches = PropertyDetails.get_potential_matches_for_tracking(property_details, locality, receptions, beds, baths, property_type)

      tracking_buyers = Trackers::Buyer.new.get_emails_of_buyer_trackers udprn
      enquiry_buyers = Trackers::Buyer.new.get_emails_of_buyer_enquiries udprn
      BuyerMailer.tracking_emails(tracking_buyers, address, last_property_status_type, update_hash["property_status_type"]).deliver_later
      BuyerMailer.enquiry_emails(enquiry_buyers, address, last_property_status_type, update_hash["property_status_type"]).deliver_later
    end
  end

  def self.add_agent_details(details, agent_id)
    agent = Agents::Branches::AssignedAgent.unscope(where: :is_developer).where(id: agent_id).last
    if agent
      branch = agent.branch
      details[:assigned_agent_first_name] = agent.first_name
      details[:assigned_agent_last_name] = agent.last_name
      details[:assigned_agent_email] = agent.email
      details[:assigned_agent_mobile] = agent.mobile
      details[:assigned_agent_title] = agent.title
      details[:assigned_agent_office_number] = agent.office_phone_number
      details[:assigned_agent_image_url] = agent.image_url
      details[:assigned_agent_branch_name] = branch.name
      details[:assigned_agent_branch_number] = branch.phone_number
      details[:assigned_agent_branch_address] = branch.address
      details[:assigned_agent_branch_website] = branch.website
      details[:assigned_agent_branch_logo] = branch.image_url
    else
      attrs = [ :assigned_agent_first_name, :assigned_agent_last_name, :assigned_agent_email, :assigned_agent_mobile, :assigned_agent_title,
                :assigned_agent_image_url, :assigned_agent_branch_name, :assigned_agent_branch_number, :assigned_agent_branch_website, 
                :assigned_agent_branch_address, :assigned_agent_branch_logo ]
      attrs.each { |attr| details[attr] = nil }
    end
  end

  def self.update_details(client, udprn, update_hash)
    response = {}
    status = 200
    es_hash = {}
    update_hash[:pictures] = update_hash['pictures'].sort_by{|x| x['priority']} if update_hash.key?('pictures')

    ### Exclude property_status_type from detail and other attrs
    property_attrs = PropertyService::DETAIL_ATTRS - (PropertyService::LOCALITY_ATTRS + PropertyService::AGENT_ATTRS + PropertyService::VENDOR_ATTRS + PropertyService::POSTCODE_ATTRS) - [:property_status_type]

    ### Update description if description is set
    update_hash[:description_set] = true if update_hash[:description]

    property_updated_cond = nil
    property_updated_cond = property_attrs.any? { |attr| update_hash.has_key?(attr) }

    update_hash[:status_last_updated] = Time.now.to_i if property_updated_cond
    update_hash[:property_status_last_updated] = Time.now.to_i if update_hash.has_key?(:property_status_type)

    details = PropertyService.bulk_details([udprn]).first
    old_details = details.deep_dup
    update_hash[:is_new_home] = update_hash[:not_yet_built] if update_hash[:not_yet_built]
    last_property_status_type = details[:property_status_type]

    ### Track previous agent id
    previous_agent_id = nil
    previous_agent_id = details[:agent_id] if details[:agent_id] && update_hash[:agent_id] && update_hash[:agent_id] != details[:agent_id]

    #begin
      ### Update snapshot of description as well
      ### No of characters = 500
      update_hash[:description_snapshot] = update_hash[:description][0..500] if update_hash[:description]

      ### If vendor id has been changed or added, add this to AddressDistrictRegister
      if update_hash[:vendor_id] && details[:vendor_id].to_i != update_hash[:vendor_id].to_i
        AddressDistrictRegister.where(udprn: udprn).update_all(vendor_registered: true, vendor_claimed_at: Time.now)
      end

      ### If price or sale price has been changed, then make them the same attribute to be stored
      if update_hash[:price] || update_hash[:sale_price]
        price = update_hash[:price]
        sale_price = update_hash[:sale_price]
        price_abs = price || sale_price
        update_hash[:price] = update_hash[:sale_price] = price_abs.to_i

        ### Clear the agents missing sale price cache 
        cache_key = "temp_method_cache_missing_sale_price_properties_for_agents_#{details[:agent_id]}"
        ardb_client = Rails.configuration.ardb_client
        ardb_client.del(cache_key)
      end

      update_hash[:percent_completed] = PropertyService.new(udprn).compute_percent_completed(update_hash, details)
      update_hash[:verification_status] = (update_hash[:percent_completed].to_i == 100)
      update_hash.delete(:percent_completed) if update_hash[:percent_completed].nan?

      ### Add details of an agent
      add_agent_details(details, update_hash[:agent_id]) if update_hash.has_key?(:agent_id) && update_hash[:agent_id].to_i != details[:agent_id].to_i
      PropertyService.attach_vendor_details(update_hash[:vendor_id], details) if update_hash[:vendor_id]
      update_hash.each{ |key, value| details[key.to_sym] = value }
      PropertyService.normalize_all_attrs(details)
      ### Normalise price attrs
      if details[:price] || details[:sale_price]
        abs_price = details[:price] || details[:sale_price]
        details[:price] = details[:sale_price] = abs_price.to_i
      end

      ### Send tracking emails for matching buyers aynschronously
      PropertyService.send_tracking_email_to_tracking_buyers(update_hash, old_details)

      (PropertySearchApi::ES_ATTRS - [:status_last_updated]).each { |key| es_hash[key] = details[key] if details[key] }
      PropertySearchApi::ADDRESS_LOCALITY_LEVELS.each { |key| es_hash[key] = details[key] if details[key] }

      details[:vanity_url] = nil
      PropertyService.update_udprn(udprn, details)

      ### Updated status of es model
      es_hash[:status_last_updated] = Time.now.localtime.to_s if property_updated_cond
      Rails.logger.info("STATUS_UPDATE_#{es_hash[:status_last_updated]}__#{property_updated_cond}") if property_updated_cond

      deleted_count = 0
      client.delete index: Rails.configuration.address_index_name, type: Rails.configuration.address_type_name, id: udprn rescue nil

      deleted_count += 1
      error = client.index index: Rails.configuration.address_index_name, type: Rails.configuration.address_type_name, id: udprn , body: es_hash
      PropertyService.update_description(udprn, update_hash[:description]) if update_hash[:description]

      deleted_count -= 1
      Rails.logger.info("ES_UPDATE_ERROR_#{udprn}_#{error}__#{es_hash}") if deleted_count != 0
      response = { message: 'Successfully updated' }
    #rescue => e
    #  Rails.logger.info "Error updating details for udprn #{udprn} => #{e}"
    #i  response = {"message" => "Error in updating udprn #{udprn}", "details" => e.message}
     # status = 500
    #end

    ### TODO: Email Offline or Daily
    perform_async_actions(details, update_hash, last_property_status_type, previous_agent_id)
    # send_email_to_trackers(udprn, update_hash, last_property_status_type, details) if update_hash.key?('property_status_type')
    Rails.logger.info("update details response = #{response}, status = #{status}")
    return response, status
  end

  def self.perform_async_actions(old_hash, new_hash, last_property_status_type, previous_agent_id=nil)
    ### Property status change email. Amber -> Green/ Red -> Amber
    if new_hash[:property_status_type] != last_property_status_type
      old_hash[:last_property_status_type] = last_property_status_type
      TrackingEmailStatusChangeWorker.perform_async(old_hash)
    end

    ### If the property has been sold
    #TrackingEmailPropertySoldWorker.perform_async(old_hash) if new_hash[:sold]

    ### If assigned agent has been changed
    if previous_agent_id
      old_hash[:reason] = new_hash[:reason]
      old_hash[:time] = Time.now.to_s
      ### It also reassigns previous enquiries to the current agent for performance wins in the enquiries panel
      AssignedAgentChangeWorker.perform_async(old_hash, previous_agent_id)
    end
    
    filtered_new_hash = {}
    TRACKING_ATTRS.each{ |t| filtered_new_hash[t] = new_hash[t] if new_hash[t] }
    if !filtered_new_hash.empty?
      agent_id = old_hash[:agent_id]
      agent_id ||= new_hash[:agent_id]

      vendor_id = old_hash[:vendor_id]
      vendor_id ||= new_hash[:vendor_id]

      PropertyEvent.create(
        udprn: old_hash[:udprn],
        attr_hash: filtered_new_hash,
        agent_id: agent_id,
        vendor_id: vendor_id
       )
     end

    if new_hash[:agent_id]
      ardb_client = Rails.configuration.ardb_client
      ardb_client.del("cache_#{new_hash[:agent_id]}_agent_new_enquiries") if previous_agent_id
    end

    if new_hash[:vendor_id]
      ardb_client = Rails.configuration.ardb_client
      ardb_client.del("cache_#{old_hash[:udprn]}_enquiries")
      ardb_client.del("cache_#{old_hash[:udprn]}_interest_info")
      ardb_client.del("cache_#{old_hash[:udprn]}_history_enquiries")
    end
  end

  def self.check_if_property_status_changed(old_status, new_status)
    old_status != new_status
  end

end

