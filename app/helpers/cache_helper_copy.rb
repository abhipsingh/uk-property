module CacheHelper
  def cache_response_and_value(cache_key, cache_parameters)
    #Rails.logger.info(params)
    latest_time = params[:latest_time].to_s
    ardb_client = Rails.configuration.ardb_client
    composite_key = cache_parameters.join('-')
    cache_response_value = ardb_client.hget("cache_response_#{action_name}","#{cache_key}")
    if params[:latest_time]
      value = ardb_client.hget("cache_response_#{action_name}","#{cache_key}")
      epoch = Time.parse(params[:latest_time]).to_i
  

      if value && epoch < value.to_i
        latest_time = Time.at(value.to_i).to_s
        response.headers['latest_time'] = latest_time
        if !cache_response_value
          yield
          ardb_client.hset("cache_response_#{action_name}","#{cache_key}", @current_response.to_json) 
        else
          @current_response = Oj.load(cache_response_value) 
        end
      elsif value && epoch >= value.to_i
        latest_time = Time.at(epoch).to_s
        response.headers['latest_time'] = latest_time
        render nothing: true, status: 304
      else
        value = Time.now.to_i
        values = ardb_client.hset("cache_response_#{action_name}","#{cache_key}", value)
        latest_time = Time.at(value).to_s
        response.headers['latest_time'] = latest_time
        if !cache_response_value
          yield
          ardb_client.hset("cache_response_#{action_name}","#{cache_key}", @current_response.to_json) 
        else
          @current_response = Oj.load(cache_response_value) 
        end
      end
    else
      latest_time = Time.now.to_s
      response.headers['latest_time'] = latest_time
      if !cache_response_value
        yield
        ardb_client.hset("cache_response_#{action_name}","#{cache_key}", @current_response.to_json) 
      else
        @current_response = Oj.load(cache_response_value) 
      end
    end
  end
  
end

