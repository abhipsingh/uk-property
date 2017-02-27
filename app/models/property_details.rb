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
    published_address += ', ' + details[:sub_building_name] if details.has_key?(:sub_building_name)
    published_address += ', ' + details[:building_name] if details.has_key?(:building_name)
    published_address += ', ' + details[:building_number] if details.has_key?(:building_number)
    published_address += ', ' + details[:dependent_thoroughfare_description] if details.has_key?(:dependent_thoroughfare_description)
    if details.has_key?(:dependent_locality) && details[:dependent_locality].is_a?(Array)
      published_address += ', ' + details[:dependent_locality].join(',')  
    else
      published_address += ', ' + details[:dependent_locality] if details.has_key?(:dependent_locality)
    end
    published_address += ', ' + details[:post_town] if details.has_key?(:post_town)
    published_address += ', ' + details[:county] if details.has_key?(:county)
    published_address += ', ' + details[:postcode] if details.has_key?(:postcode)
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
    remote_es_url = Rails.configuration.remote_es_url
    response = Net::HTTP.get(URI.parse(remote_es_url + '/addresses/address/' + udprn.to_s))
    response = Oj.load(response) rescue {}
    response['address'] = address(response["_source"])
    response
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

  def self.send_email_to_trackers udprn, update_hash, last_property_status_type, property_details
    if property_details.present?
      address = property_details["address"]

      street = property_details["dependent_thoroughfare_description"]
      locality = property_details["dependent_locality"]

      receptions = property_details["receptions"]
      baths = property_details["baths"]
      beds = property_details["beds"]
      property_type = property_details["property_type"]
      @street_potential_matches = get_potential_matches_for_tracking(property_details, street, receptions, beds, baths, property_type)
      @locality_potential_matches = get_potential_matches_for_tracking(property_details, locality, receptions, beds, baths, property_type)
      
      tracking_buyers = Trackers::Buyer.new.get_emails_of_buyer_trackers udprn
      enquiry_buyers = Trackers::Buyer.new.get_emails_of_buyer_enquiries udprn
      BuyerMailer.tracking_emails(tracking_buyers, address, last_property_status_type, update_hash["property_status_type"]).deliver_now
      BuyerMailer.enquiry_emails(enquiry_buyers, address, last_property_status_type, update_hash["property_status_type"]).deliver_now
    end
  end

  def self.get_potential_matches_for_tracking(property_details, hash_str, receptions, beds, baths, property_type)
    locality_hashes = property_details['hashes'].find{ |hashes| hashes.end_with? hash_str}
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
  
  def self.update_details(client, udprn, update_hash)
    #Rails.logger.info("HELLO_#{update_hash}")
    property_details = details(udprn)['_source']
    last_property_status_type = property_details['property_status_type']
    update_hash['status_last_updated'] = Time.now.to_s[0..Time.now.to_s.rindex(" ")-1]
    client.update index: Rails.configuration.address_index_name, type: 'address', id: udprn,
                        body: { doc: update_hash }
    if update_hash.key?('property_status_type')
      ###send_email_to_trackers(udprn, update_hash, last_property_status_type, property_details)
    end
  end

end

