### Base controller
class PropertiesController < ActionController::Base

  def edit
    udprn = params[:udprn]
    @udprn = udprn
    property = JSON.parse(Net::HTTP.get(URI.parse("http://localhost:9200/addresses/address/#{udprn}")))
    property = property['_source'] if property.has_key?('_source')
    @building_unit = ''
    @building_unit += property['building_number'] if property.has_key?('building_number')
    @building_unit += ', ' + property['sub_building_name'] if property.has_key?('sub_building_name')
    @building_unit += ', ' + property['building_name'] if property.has_key?('building_name')
    @postcode = property['postcode']
    @historical_details = PropertyHistoricalDetail.where(udprn: udprn).select([:price, :date])
    @address = PropertyDetails.address(property)
    render 'edit'
  end



end
