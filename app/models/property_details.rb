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
    published_address += ', ' + details[:dependent_locality] if details.has_key?(:dependent_locality)
    published_address += ', ' + details[:post_town] if details.has_key?(:post_town)
    published_address += ', ' + details[:county] if details.has_key?(:county)
    published_address += ', ' + details[:postcode] if details.has_key?(:postcode)
    published_address[1, published_address.length-1]
  end
end

