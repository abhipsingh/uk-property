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

end

