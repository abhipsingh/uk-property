class AddressDumper
  def self.dump_addresses
    # scroll_id = 'cXVlcnlBbmRGZXRjaDsxOzYxOnpaNF9od3p0UWFtSTAzMllZd2pwbXc7MDs='
    scroll_id = 'cXVlcnlBbmRGZXRjaDsxOzYyOnpaNF9od3p0UWFtSTAzMllZd2pwbXc7MDs='
    file_counter = 0
    glob_counter = 0
    loop do
      file = File.open("/mnt3/address_files/address_file_#{glob_counter}", 'w')
      scroll_hash = { scroll: '300m', scroll_id: scroll_id }
      response , _status = post_url_new(scroll_hash)
      udprns = JSON.parse(response)["hits"]["hits"].map { |t| t['_source']['udprn']  }
      response_arr = Oj.load(response)['hits']['hits'].map { |e| e['_source'] }
      break if udprns.length == 0
      body = []
      udprns.each_with_index do |udprn, index|
        details = response_arr[index]
        address = details['udprn'].to_s + '|' + PropertyDetails.address(details)
        file.puts(address)
      end
      file.close
      # p response['items'].first
      p "#{glob_counter} pASS completed for #{body.count} ITEMS"
      glob_counter += 1
    end
  end

  def self.post_url_new(query = {}, index_name='property_details', type_name='property_detail')
    uri = URI.parse(URI.encode("http://172.31.18.90:9200/_search/scroll"))
    query = (query == {}) ? "" : query.to_json
    http = Net::HTTP.new(uri.host, uri.port)
    result = http.post(uri,query)
    body = result.body
    status = result.code
    return body, status
  end
end
