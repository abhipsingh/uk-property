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
    response['address'] = address(response)
    response
  end

  ### Always returns the udprns of the properties which have the same beds, baths, receptions,
  ### and the same sector as the udprn.
  def self.similar_properties(udprn)
    property_details = details(udprn)['_source']
    search_params = {
      min_beds: property_details['beds'],
      max_beds: property_details['beds'],
      min_baths: property_details['baths'],
      max_baths: property_details['baths'],
      min_receptions: property_details['receptions'],
      max_receptions: property_details['receptions'],
      property_types: property_details['property_type'],
      sector: property_details['sector'],
      fields: 'udprn'
    }

    p search_params
    api = PropertyDetailsRepo.new(filtered_params: search_params)
    api.apply_filters
    body, status = api.fetch_data_from_es
    udprns = []
    if status.to_i == 200
      udprns = body.map { |e| e['udprn'] }
    end
    udprns
  end

  def self.historic_pricing_details(udprn)
     VendorApi.new(udprn.to_s).calculate_valuations
  end

end

