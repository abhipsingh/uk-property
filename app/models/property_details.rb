require 'base64'
class PropertyDetails
  attr_reader :attributes

  def initialize(attributes={})
    @attributes = attributes
  end

  def to_hash
    @attributes
  end

  def self.address(details)
    details = details.with_indifferent_access
    published_address = ''
    published_address += ', ' + details[:sub_building_name] if details[:sub_building_name]
    published_address += ', ' + details[:building_name] if details[:building_name]
    published_address += ', ' + details[:building_number].to_s if details[:building_number]
    published_address += ', ' + details[:dependent_thoroughfare_description] if details[:dependent_thoroughfare_description]
    published_address += ', ' + details[:thoroughfare_description] if details[:thoroughfare_description]
    published_address += ', ' + details[:double_dependent_locality] if details[:double_dependent_locality]
    if details[:dependent_locality] && details[:dependent_locality].is_a?(Array)
      published_address += ', ' + details[:dependent_locality].join(',')
    else
      published_address += ', ' + details[:dependent_locality] if details[:dependent_locality]
    end
    published_address += ', ' + details[:post_town] if details[:post_town]
    published_address += ', ' + details[:county] if details[:county]
    published_address += ', ' + details[:postcode] if details[:postcode]
    published_address[1, published_address.length-1]
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
    details['address'] = address(details)
    details['udprn'] = udprn
    #details['vanity_url'] = vanity_url(details['address'])
    { '_source' => details }
  end

  def self.vanity_url(address)
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
      BuyerMailer.tracking_emails(tracking_buyers, address, last_property_status_type, update_hash["property_status_type"]).deliver_now
      BuyerMailer.enquiry_emails(enquiry_buyers, address, last_property_status_type, update_hash["property_status_type"]).deliver_now
    end
  end

  def self.update_details(client, udprn, update_hash)
    response = {}
    status = 200
    es_hash = {}
    update_hash['pictures'] = update_hash['pictures'].sort_by{|x| x['priority']} if update_hash.key?('pictures')
    update_hash['status_last_updated'] = Time.now.to_s[0..Time.now.to_s.rindex(" ")-1]
    update_hash.symbolize_keys!
    details = PropertyService.bulk_details([udprn]).first
    last_property_status_type = details[:property_status_type]
    begin
      update_hash.each{|key, value| details[key] = value }
      PropertyService.normalize_all_attrs(details)
      PropertySearchApi::ES_ATTRS.each { |key| es_hash[key] = details[key] if details[key] }
      PropertySearchApi::ADDRESS_LOCALITY_LEVELS.each { |key| es_hash[key] = details[key] if details[key] }
      PropertyService.update_udprn(udprn, details)
      client.delete index: Rails.configuration.address_index_name, type: Rails.configuration.address_type_name, id: udprn rescue nil
      client.index index: Rails.configuration.address_index_name, type: Rails.configuration.address_type_name, id: udprn , body: es_hash
      response = { message: 'Successfully updated' }
    rescue => e
      Rails.logger.info "Error updating details for udprn #{udprn} => #{e}"
      response = {"message" => "Error in updating udprn #{udprn}", "details" => e.message}
      status = 500
    end
    ### TODO: Email Offline or Daily
    perform_async_actions(details, update_hash, last_property_status_type)
    # send_email_to_trackers(udprn, update_hash, last_property_status_type, details) if update_hash.key?('property_status_type')
    Rails.logger.info("update details response = #{response}, status = #{status}")
    return response, status
  end

  def self.perform_async_actions(old_hash, new_hash, last_property_status_type)
    if new_hash[:property_status_type] != last_property_status_type
      old_hash[:last_property_status_type] = last_property_status_type
      TrackingEmailStatusChangeWorker.perform_async(old_hash)
    end

    if new_hash[:sold]
      TrackingEmailPropertySoldWorker.perform_async(old_hash)
    end
  end

  def self.check_if_property_status_changed(old_status, new_status)
    old_status != new_status
  end

end

