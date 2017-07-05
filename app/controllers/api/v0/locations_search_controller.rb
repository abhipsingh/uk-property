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
        postcode_cond = check_if_postcode?(params[:str].upcase, regexes)
        if postcode_cond
          str = params[:str].upcase.strip
        else
          str = params[:str].gsub(',',' ').downcase.strip
        end
        suggestions, status = get_results_from_es_suggest(str)
        Rails.logger.info(suggestions)
        predictions = Oj.load(suggestions)['postcode_suggest'][0]['options'] rescue []
        predictions.each { |t| t['score'] = t['score']*100 if t['payload']['hash'] == params[:str].upcase.strip }
        predictions.sort_by!{|t| (1.to_f/t['score'].to_f) }
        final_predictions = []
        predictions = predictions.each do |t|
          hierarchy = t['payload']['hierarchy_str'].split('|')
          output = nil
          if t['payload']['type'] == 'building_type'&& hierarchy[0].to_i > 0
            output = hierarchy[0] + ' ' + hierarchy[1..-1].join(', ')
          else
            output = hierarchy.join(', ')
          end
          if t['payload']['postcode'] && !postcode_cond
            output = output + ', ' + t['payload']['postcode'].to_s
          end
          final_predictions.push({ hash: t['payload']['hash'], output: output, location_type: t['payload']['type']  })
        end
        
        #Rails.logger.info(predictions)
        final_predictions = final_predictions.group_by{ |t| t[:location_type] }
        render json: final_predictions, status: status
      end

      def get_results_from_es_suggest(query_str, size=50)
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
