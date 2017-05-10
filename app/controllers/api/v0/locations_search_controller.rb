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
    class LocationsSearchController < ActionController::Base
      ### Autosuggest api (the new one)
      ### curl -XGET http://localhost/api/v0/locations/predict?str=liv
      def predict
        regexes = [ /^([A-Z]{1,2})([0-9]{0,3})$/, /^([0-9]{1,2})([A-Z]{0,3})$/]
        str = nil
        if check_if_postcode?(params[:str].upcase, regexes)
          str = params[:str].upcase
        else
          str = params[:str].gsub(',',' ').downcase
        end
        suggestions, status = get_results_from_es_suggest(str)
        Rails.logger.info(suggestions)
        predictions = [ ]
        predictions = Oj.load(suggestions)['postcode_suggest'].map { |e| e['options'].map{ |t| { hash: t['payload']['hash'], output: (t['payload']['hierarchy_str'].split('|').join(', ') + ', '+ t['payload']['postcode'] rescue ''  ), location_type: t['payload']['type'] } } }.flatten if Oj.load(suggestions)['postcode_suggest']
        #Rails.logger.info(predictions)
        predictions = predictions.group_by{ |t| t[:location_type] }
        render json: predictions, status: status
      end

      def get_results_from_es_suggest(query_str, size=100)
        query_str = {
          postcode_suggest: {
            text: query_str,
            completion: {
              field: 'suggest',
              size: size
            }
          }
        }
        res, code = post_url('locations', query_str)
      end

      def check_if_postcode?(str, regexes)
        str.split(" ").each_with_index.all?{|i, ind| i.match(regexes[ind]) }
      end
      
      def post_url(index, query = {}, type='_suggest', host='localhost')
        uri = URI.parse(URI.encode("#{ES_EC2_URL}/#{index}/#{type}")) if host != 'localhost'
        uri = URI.parse(URI.encode("http://#{host}:9200/#{index}/#{type}")) if host == 'localhost'
        query = (query == {}) ? "" : query.to_json
        http = Net::HTTP.new(uri.host, uri.port)
        result = http.post(uri,query)
        body = result.body
        status = result.code
        return body, status
      end
    end
  end
end
