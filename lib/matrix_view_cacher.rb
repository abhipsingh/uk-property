module MatrixViewCacher
  
  def cache_hash_str(hash_str)
    ardb_client = Redis.new( host: Rails.configuration.ardb_host,port: Rails.configuration.ardb_port,db: 4,timeout: 600 )
    matrix_view_service = MatrixViewService.new(hash_str: hash_str)
    values = MatrixViewService::POSTCODE_MATCH_MAP["#{matrix_view_service.level}"]
    values ||= MatrixViewService::ADDRESS_UNIT_MATCH_MAP["#{matrix_view_service.level}"]
    url = "http://35.176.93.242/addresses/matrix_view?hash_type=text&str=#{hash_str}"
    resp = Net::HTTP.get_response(URI.parse(url))
  
    possible_children = values.map{|t| t[0]}.map(&:to_sym) - [matrix_view_service.level.to_sym]
    children_arr = []
    child_hash_strs = []
    if resp.code.to_i == 200
      body = resp.body
      response = Oj.load(body)
  
      possible_children.each do |child|
        child_key = child.to_s.pluralize
        arr = response[child_key].map{|t| [t["hash_str"], t['flat_count']]}
        children_arr.push(arr)
        hash_strs = response[child_key].map{|t| t["hash_str"] }
        p matrix_view_service.level
        if !(matrix_view_service.level == :thoroughfare_description || matrix_view_service.level == :dependent_thoroughfare_description || matrix_view_service.level == :unit)
          child_hash_strs = child_hash_strs + hash_strs
        end
      end
       
      #ardb_client.set(hash_str, children_arr.to_json)
    end
    p child_hash_strs
    child_hash_strs
  end

  def cache_recursive_hash_str(hash_str)
    children = cache_hash_str(hash_str)
    if children.length == 0
    else
      p children
      children.each { |child| cache_recursive_hash_str(child) }
    end
  end

  def cache_post_town_hash_strs
    post_town_hashes = []
    MatrixViewCount::POST_TOWNS.each do |post_town|
      url = "http://35.176.93.242/addresses/predictions?str=#{post_town}"
      resp = Net::HTTP.get_response(URI.parse(url))
      if resp.code.to_i == 200
        body = Oj.load(resp.body)
        post_town = nil
        # p body[0]
        post_town = body[0]['hash'] if body[0]['type'] == 'post_town'
        post_town_hashes.push(post_town) if post_town
      else
        p resp.code.to_i
      end
    end;nil
    post_town_hashes.each { |pt_hash| cache_recursive_hash_str(pt_hash) }
  end

end

