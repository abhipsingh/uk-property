class GoogleApiCrawler
  # include Sidekiq::Worker
  # include Sidetiq::Schedulable

  # recurrence { daily }
  #https://maps.googleapis.com/maps/api/streetview?size=400x400&location=40.720032,-73.988354&fov=90&heading=235&pitch=10&key=AIzaSyBfcSipqHZEZooyoKqxpLzVu3u-NuEdIt8

  URL_PREFIX = 'https://maps.googleapis.com/maps/api/streetview'
  API_KEY = 'AIzaSyBfcSipqHZEZooyoKqxpLzVu3u-NuEdIt8'

  REQUEST_PARAMS = {
    size: '640*640',
    location: nil,
    fov: 90,
    pitch: 0,
    key: API_KEY
  }

  def perform
    time = Time.now
    day = time.day
    month = time.month
    val = ((month - 5) * 30) + day
    file_name = '/mnt3/random_uuids_' + val.to_s + '.log'
    udprns = []
    batch_number = 0
    File.foreach(file_name) do |line|
      udprns << line
    end
    threads = []
    query_fields = [ :sub_building_name, :building_name, :building_number, :dependent_thoroughfare_description, :dependent_locality, :post_town ]

    udprns.each_slice(10) do |batch|

      threads << Thread.new do 
        addresses = []
        docs = []
        
        ### Prepare queries
        batch.each do |udprn|
          docs.push(
            {
              _id: udprn.strip,
              _source: query_fields
            }
          )
        end
        query = { docs: docs }
        
        ### Extract response
        response, status = post_url(query, Rails.configuration.address_index_name, 'address', '_mget')
        if status.to_i == 200
          body = Oj.load(response)
          body['docs'].each do |each_doc|
            addresses << address(each_doc['_source'])
          end
        end
        ### Extract the images and upload to S3 for each address
        addresses.each_with_index do |each_address, index|
          process_each_address(each_address, docs[index][:_id])
        end
      end

      threads.map(&:join)
      batch_number += 1
      p "#{batch_number} Batch completed"
    end

  end

  def process_each_address(address, udprn)
    request_params = REQUEST_PARAMS
    request_params[:location] = address
    url = URL_PREFIX + '?' + request_params.to_query
    uri = URI.parse(url)
    file_name = "#{udprn}_street_view.jpg"
    begin
      Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        request = Net::HTTP::Get.new uri
        http.request request do |response|
          open file_name, 'wb' do |io|
            response.read_body do |chunk|
              io.write chunk
            end
          end
        end
      end
      s3 = Aws::S3::Resource.new
      obj = s3.bucket('propertyuk').object(file_name)
      res = obj.upload_file(file_name, acl: 'public-read')
      File.delete(file_name) if res
      File.open('successful_street_view.txt', 'a') { |f| f.puts udprn }
    rescue StandardError => e
      Rails.logger.info("STREET_VIEW_CRAWLING_FAILED_FOR_#{udprn}")
    end
  end

  def address(doc_source)
    if doc_source
      dependent_locality = doc_source['dependent_locality']
      dependent_thoroughfare_description = doc_source['dependent_thoroughfare_description']
      thoroughfare_descriptor = doc_source['thoroughfare_descriptor']
      building_number = doc_source['building_number']
      building_name = doc_source['building_name']
      sub_building_name = doc_source['sub_building_name']
      post_town = doc_source['post_town']
      address = append_unit('', sub_building_name)
      address = append_unit(address, building_name)
      address = append_unit(address, building_number)
      street = (thoroughfare_descriptor || dependent_thoroughfare_description)
      address = append_unit(address, street)
      if street.nil?
        if dependent_locality.is_a?(String)
          address = append_unit(address, dependent_locality)
        elsif dependent_locality.is_a?(Array)
          address = append_unit(address, dependent_locality[0])
        end
      end
      address = append_unit(address, post_town.capitalize)
    end
    address
  end

  def append_unit(value, unit)
    if (!unit.nil?) && (!unit.empty?)
      if value.length > 0
        value = value + ', ' + unit
      else
        value = unit
      end
    end
    value
  end  

  def post_url(query = {}, index_name='property_details', type_name='property_detail', endpoint='_search')
    uri = URI.parse(URI.encode("#{Rails.configuration.remote_es_url}/#{index_name}/#{type_name}/#{endpoint}"))
    query = (query == {}) ? "" : query.to_json
    http = Net::HTTP.new(uri.host, uri.port)
    result = http.post(uri,query)
    body = result.body
    status = result.code
    return body,status
  end

  def self.match_udprns_to_historical_data
    file = File.open('/mnt3/csv/lspm.csv', 'a')
    #g_zero_file = File.open('/mnt3/lspgz.csv', 'a')
    #zero_file = File.open('/mnt3/lspz.csv', 'a')
    #file = File.open('/mnt3/lspm.csv', 'a')
    count = 0
    urls = []
    threads = []
    uuids = []
    size = 1000
    postcodes = []
    length_count_zero = 0
    length_count_g_zero = 0
    File.open('/home/ec2-user/pp-complete.csv', 'r').each_line do |line|
      parts = line.scrub.strip.split(',').map{|t| t.gsub(/"/, '')}
      price = parts[1].to_i
      date = parts[2].to_s.split(' ')[0]
      property_type = parts[6]
      tenure = parts[4]
      paon = parts[7].gsub('.','').downcase
      saon = parts[8].gsub('.','').downcase
      street = parts[9].gsub('.','').downcase
      locality = parts[10].downcase
      post_town = parts[11].downcase
      postcode = parts[3]
      address_parts = []
      address_str = nil
      uuid = parts[0]
      if locality == post_town
        address_parts = [ saon, paon, street, post_town ].select{|t| !t.strip.empty? }
      else
        address_parts = [ saon, paon, street, locality, post_town ].select{|t| !t.strip.empty? }
      end
      address_str = address_parts.join(' ')
      #begin 
        urls.push({str: address_str, uuid: uuid, date: date, price: price, tenure: tenure, property_type: property_type, postcode: postcode})
        if urls.length == size
          query = {}
          urls.each_with_index do |each_url, index|
            query["suggest_#{index}".to_sym] = {:text=>urls[index][:str], :completion=>{:field=>"suggest", :size=>10}}
          end 
          body, status = PropertyService.post_url(Rails.configuration.location_index_name, nil, '_suggest' , query)
          if status.to_i == 200
            resp = Oj.load(body)
            (0..size-1).to_a.each do |elem|
              each_resp = resp["suggest_#{elem}"][0]['options']
              if each_resp.length == 1
                udprn_hash = each_resp[0]['text']
                udprn = udprn_hash.split('_').first.to_i
                file.puts("#{urls[elem][:uuid]}|#{udprn}|#{urls[elem][:date]}|#{urls[elem][:price]}|#{urls[elem][:tenure]}|#{urls[elem][:property_type]}")
#              elsif each_resp.length > 1
#                g_zero_file.puts("#{urls[elem][:uuid]}|#{udprn}|#{urls[elem][:date]}|#{urls[elem][:price]}|#{urls[elem][:tenure]}|#{urls[elem][:property_type]}")
#                length_count_g_zero += 1
#              elsif each_resp.length == 0
#                #p resp["suggest_#{elem}"][0] 
#                #p urls[elem][:postcode]
#                zero_file.puts("#{urls[elem][:uuid]}|#{udprn}|#{urls[elem][:date]}|#{urls[elem][:price]}|#{urls[elem][:tenure]}|#{urls[elem][:property_type]}")
#                length_count_zero += 1
              end
            end
          end
          urls = []
        end 
      #rescue Exception
      #end 
      count += 1
      Rails.logger.info("COUNT #{count/10000}") if count % 10000 == 0
    end
    p "Rows having greater than zero possibilities #{length_count_g_zero}"
    p "Rows having zero possibilities #{length_count_zero}"
    #zero_file.close
    #g_zero_file.close
    file.close
  end

end

