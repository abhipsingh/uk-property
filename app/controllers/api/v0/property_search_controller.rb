#### Potential results API
#### http://ec2-52-66-124-42.ap-south-1.compute.amazonaws.com/api/v0/properties/search?hash_str=HEREFORD_City%20Centre_Lingen%20Avenue&hash_type=text&match_type=Potential&buyer_status=Green&max_budget=130000
#### --------------------------------------------------------------------------------------------------------------------------------------
#### Matrix view API filtered by filters
#### http://ec2-52-66-124-42.ap-south-1.compute.amazonaws.com/addresses/matrix_view?str=Lingen%20Avenue&match_type=Potential&buyer_status=Green
#### --------------------------------------------------------------------------------------------------------------------------------------
#### Featured type APIs
#### http://ec2-52-66-124-42.ap-south-1.compute.amazonaws.com/api/v0/properties/search?hash_str=HEREFORD_City%20Centre_Lingen%20Avenue&hash_type=text&match_type=Potential&buyer_status=Amber&max_budget=160000&listing_type=Featured
#### --------------------------------------------------------------------------------------------------------------------------------------
#### Featured type APIs
#### http://ec2-52-66-124-42.ap-south-1.compute.amazonaws.com/addresses/predictions?str=Lingen%20Avenue
#### --------------------------------------------------------------------------------------------------------------------------------------

module Api
  module V0
    class PropertySearchController < ActionController::Base
      include EventsHelper
      def search
        api = ::PropertySearchApi.new(filtered_params: params)
        result, status = api.filter
        result = result[:results]#.sort_by{|t| t[:score]}.reverse
        result = result.each{|t| t[:photo_urls] = [] }
        result = result.each{ |t| t[:photo_urls] = [ process_image(t) ] + t[:photo_urls] }
        render :json => result, :status => status
      end

      ### curl -XGET 'http://localhost/api/v0/properties/matching/count?hash_str=LIVERPOOL&hash_type=Text&count=true'
      def matching_property_count
        ## hash_str compulsory?
        api = ::PropertySearchApi.new(filtered_params: params)
        result, status = api.matching_property_count
        render :json => result, :status => status
      end
      
      #### Details Api for a udprn
      #### curl -XGET 'http://localhost/api/v0/properties/details/10968961'
      def details
        udprn = params[:property_id].to_i
        details_json = PropertyDetails.details(udprn)['_source']
        details_json['photo_urls'] =  process_image(details_json)
        details_json['description'] = PropertyService.get_description(udprn)
        render json: { details: details_json }, status: 200
      end

    end
  end
end
