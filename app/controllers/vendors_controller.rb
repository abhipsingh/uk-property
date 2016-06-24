class VendorsController < ApplicationController
  def valuations
    property_id = params[:udprn]
    vendor_api = VendorApi.new(property_id)
    vendor_api.calculate_valuations
    render json: valuation_info
  end

  def quotes
    property_id = params[:udprn]
    vendor_api = VendorApi.new(property_id)
    quotes = vendor_api.calculate_quotes(branch_ids.split(',').map(&:to_i))
    render json: quotes
  end
end