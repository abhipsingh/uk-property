require 'net/http'
require 'nokogiri'
require 'open-uri'
require 'csv'

module ZooplaCrawler
  CHARACTERS = (10...36).map{ |i| i.to_s 36}


  URL_PREFIX = 'https://www.zoopla.co.uk/find-agents/estate-agents/directory/'
  BASE_URL = 'http://www.zoopla.co.uk/'
  HTTPS_BASE_URL = 'https://www.zoopla.co.uk/'
  CONN = ActiveRecord::Base.connection
  KLASS = Agents::Branches::CrawledProperty
  def self.process_agent_url(agent_url, agent_id)
    page = 1
    page_size = 100
    loop do
      url = agent_url + "?page_size=#{page_size}&pn=#{page}"
      response = generic_url_processor(url)
      page += 1
      if response
        html = Nokogiri::HTML(response)
        b = html.css("div.agents-results").css("h2").css("a")
        hrefs = b.map{ |t| t['href'] }
        Rails.logger.info("Broken") if hrefs.empty?
        break if hrefs.empty?
        names = b.map{ |t| t.text }
        addresses = html.css("div.agents-results").css("p").css("span").map{ |t| t.text }
        names.each_with_index do |name, index|
          begin
            Agents::Branch.create(name: name, property_urls: hrefs[index], address: addresses[index], agent_id: agent_id)
          rescue Exception => e
            p "#{name}_#{hrefs[index]}_#{addresses[index]}_#{agent_id}"
          end
        end
      else
        break
      end
    end
  end

  def self.generic_url_processor(url,limit = 10)
    Rails.logger.info("Why did this happen") if url == "https://www.zoopla.co.uk/"
    return nil if url == "https://www.zoopla.co.uk/"
    uri = URI.parse(url) rescue nil
    body = nil
    Rails.logger.info("CRAWLING #{url}|____#{limit}")
    if uri && uri.class == URI::HTTP || uri.class == URI::HTTPS
      response = Net::HTTP.get_response(uri)
      case response.code.to_i
      when 200 then body = response.body
      when 301 then 
        Rails.logger.info("REDIRECTION HAPPENING #{response['location']}")
        body = generic_url_processor(response['location'], limit -1)
      else
        Rails.logger.info("FAILURE_TO_CRAWL_#{url}_#{response.code}")
      end
    end
    body
  end

  def self.perform_agent_crawling
    CHARACTERS.each do |each_character|
      url = URL_PREFIX + each_character + '#directory'

      response = generic_url_processor(url)

      if response
        p "CRAWLED AGENT URL #{url}"
        html = Nokogiri::HTML(response)
        links = html.css('div.agents-az').css('li').css('a').map{|t| t['href'] }
        names = html.css('div.agents-az').css('li').css('a').map{|t| t.text }

        ids = []
        names.each_with_index do |name, index|
          agent =  Agent.where(name: name, branches_url: links[index]).first
          if agent.nil?
            agent = Agent.create(name: name, branches_url: links[index])
          end
          ids.push(agent.id)
        end

        crawlable_urls = links.map { |e|  HTTPS_BASE_URL + e }
        crawlable_urls.each_with_index do |agent_url, index|
          p "CRAWLED URLS #{agent_url}"
          process_agent_url(agent_url, ids[index])
        end
      end
    end
  end

  def self.perform_crawling_sale_properties(min_value=0, max_value=1000)
    url_prefix = "https://www.zoopla.co.uk/for-sale/branch/"
    p 'started'
    max_thread_count = 20
    thread_count = 0
    threads = []
    batch = 0
    Agents::Branch.where("name LIKE 'A%'").where("id > ?", min_value).where("id < ?", max_value).select([:id, :property_urls]).find_each do |branch|
        branch_suffix = branch.property_urls.split("/").last
        p "CRAWLED_Strted#{branch.id}"
        perform_each_branch_crawl(branch_suffix, branch.id)
        p "CRAWLED_Ended#{branch.id}"
        # threads << Thread.new { perform_each_branch_crawl(branch_suffix, branch.id) }
        # thread_count += 1
        # if thread_count > max_thread_count
        #   threads.map(&:join)
        #   threads = []
        #   thread_count = 0
        #   batch += 1
        #   p "CRAWLED_ended #{batch}"
        GC.start(full_mark: true, immediate_sweep: true)
      # end
    end
  end

  def self.perform_each_branch_crawl(branch_suffix, branch_id)
    page_size = 100
    url_prefix = "https://www.zoopla.co.uk/for-sale/branch/"
    page = 1
    loop do
      url = url_prefix + branch_suffix + "/?page_size=#{page_size}&pn=#{page}"
      response = generic_url_processor(url)
      if response
        property_urls = Nokogiri::HTML(response).css('div.listing-results-right h2.listing-results-attr a').map{|t| t['href']}
        property_urls = property_urls.uniq
        Rails.logger.info("NO_URLS_FOUND for #{url}") if property_urls.empty?
        # Rails.logger.info("URLS_FOUND for #{property_urls}") if !property_urls.empty?
        break if property_urls.empty?
        property_ids = property_urls.map{ |t| File.basename(t) }
        property_ids = property_ids.map{ |t| t.to_i }
        property_ids = property_ids.uniq
        existing_property_ids = KLASS.where(zoopla_id: property_ids).pluck(:zoopla_id)
        relevant_property_ids = property_ids - existing_property_ids
        relevant_property_ids.map { |property_id| crawl_property(property_id, branch_id) }
        page += 1
      else
        Rails.logger.info("FAILED TO CRAWL PROPERTIES FOR BRANCH #{branch_suffix} and branch id #{branch_id}")
        break
      end
    end
  end

  def self.crawl_property(property_id, branch_id)
    url = HTTPS_BASE_URL + 'for-sale/details/' + property_id.to_s
    uri = URI.parse(url)
    zoopla_id = property_id
    response = generic_url_processor(url)
    stored_response = {}
    if response
      html = Nokogiri::HTML(response)
      latitude = html.css('meta[itemprop="latitude"]')[0]['content'].to_f rescue nil
      longitude = html.css('meta[itemprop="longitude"]')[0]['content'].to_f rescue nil
      property = nil
      if KLASS.where(zoopla_id: property_id).count > 0
        property = KLASS.where(zoopla_id: property_id).last
      end
      html.css('style').remove
      title = html.css('div#listing-details').css('h2')[0].text rescue nil
      address = html.css('div.listing-details-address').css('h2').text rescue nil
      street_address = html.css('div.listing-details-address').css('meta')[0]['content'] rescue nil
      address_locality = html.css('div.listing-details-address').css('meta')[1]['content'] rescue nil
      address_region = html.css('div.listing-details-address').css('meta')[2]['content'] rescue nil
      beds = html.css('div.listing-details-attr').css('span.num-beds')[0].text.to_i rescue nil
      baths = html.css('div.listing-details-attr').css('span.num-baths')[0].text.to_i rescue nil
      receptions = html.css('div.listing-details-attr').css('span.num-reception')[0].text.to_i rescue nil
      images_original_prefix = html.css('ul#images_original').css('a')[0]['href'] rescue nil
      # original_images_url = BASE_URL + images_original_prefix.to_s
      # images_response = nil
      # if images_original_prefix
      #   images_response = generic_url_processor(original_images_url) 
      # end
      image_urls = []
      features = html.css('div#listing-details').css('h3').map{|t| t.parent}.first.css('li').map{|t| t.text} rescue []
      description = html.css('div#listing-details').css('h3').map{|t| t.parent}.second.css('div.top').text.strip rescue ''
      agent_logo = html.css('img.agent_logo')[0]['src'] rescue nil
      # if images_response
      #   images_html = Nokogiri::HTML(images_response)
      #   image_urls = images_html.css('a').css('img').map{ |t| t['src'] }
      # end
      stored_response[:title] = title
      stored_response[:address] = address
      stored_response[:street_address] = street_address
      stored_response[:address_locality] = address_locality
      stored_response[:address_region] = address_region
      stored_response[:latitude] = latitude
      stored_response[:longitude] = longitude
      stored_response[:beds] = beds
      stored_response[:baths] = baths
      stored_response[:receptions] = receptions
      # stored_response[:image_urls] = image_urls
      stored_response[:description] = description
      stored_response[:features] = features
      stored_response[:agent_logo] = agent_logo
      # p stored_response
      postcode = html.css("meta[property='og:postal-code']").first['content'] rescue nil
      agent_street_address = html.css('span[itemprop="streetAddress"]').text
      stored_response[:agent_street_address] = agent_street_address
      agent_postcode = html.css('span[itemprop="postalCode"]').text
      stored_response[:agent_postcode] = agent_postcode
      opening_hours = html.css('ul.opening-hours__week li').map{|t| t.text.strip}.map{|t| t.split(":\n")}.inject({}){|hash,t| hash[t[0]]=t[1].reverse.strip.reverse;hash }
      stored_response[:opening_hours] = opening_hours
      script_node = html.css("head script").select{|t| t.text.index("googletag.pubads().setTargeting")}.last
      floorplan_url = html.css('img.floorplan-img')[0]['src'] rescue nil
      stored_response[:floorplan_url] = floorplan_url if floorplan_url
      details_map = {}
      if script_node
        details_arr = script_node.text.scan(/googletag.pubads\(\).setTargeting\((.+?)\);/)
        value = nil
        details_arr.each do |each_arr_tag|
          values = each_arr_tag[0].split(',')
          key = values[0].gsub("\"","")
          key = key.strip
          value = values[1].gsub("'", "''")
          value = value.gsub("\"", '')
          value = value.strip
          details_map[key] = value
        end
      end

      res = nil
      if title && address && latitude && longitude && property.nil?
        res = KLASS.create(stored_response: stored_response, html: nil, branch_id: branch_id, postcode: postcode, zoopla_id: zoopla_id, additional_details: details_map)
        Rails.logger.info("FINISHED Crawling for property #{res.id}")
      elsif property
        property.update_attributes(stored_response: stored_response, html: nil, branch_id: branch_id, postcode: postcode,  additional_details: details_map) rescue nil
        Rails.logger.info("FINISHED Crawling for existing property #{property.id}")
      end
      # if res.nil?
      #   binding.pry
      # end
      Rails.logger.info("CRAWLING_FAILED_FOR_#{branch_id}_#{url}") if res.nil? && property.nil?
    end
  end

  def self.crawl_images(min_value=0, max_value=8000)
    s3 = Aws::S3::Resource.new
    KLASS.connection.execute(KLASS.where.not(zoopla_id: nil).where("id>?", min_value).where("id<?", max_value).select([:id, :zoopla_id]).to_sql).each do |property|
      threads = []
      url = "http://www.zoopla.co.uk/for-sale/details/photos/#{property['zoopla_id']}"
      response = Net::HTTP.get_response(URI.parse(url))
      html = Nokogiri::HTML(response.body)
      property_id = property['id']
      image_urls = html.css("div a[target='_blank']").css('img').map{ |t| t['src'] }
      image_urls.each do |url|
        threads << Thread.new do
          s3_file_name = "#{property_id}/#{File.basename(url)}"
          file_name = File.basename(url)
          begin
            open(url,"User-Agent" => "Whatever you want here") {|f|
              File.open(file_name,"wb") do |file|
                file.puts f.read
              end
            }
            obj = s3.bucket('propertyuk').object(s3_file_name)
            obj.upload_file(file_name, acl: 'public-read')
            File.delete(file_name)
          rescue OpenURI::HTTPError => e
            Rails.logger.info("FAILED_TO_CRAWL_IMAGE_WITH_URL_#{url}")
          rescue Errno::ENOENT => e
            Rails.logger.info("FILE_ERROR_#{property['id']}_#{e}")
          rescue URI::InvalidURIError => e
            Rails.logger.info("INVALID_URI_ERROR_#{property['id']}_#{e}")
          rescue Net::ReadTimeout => e
            Rails.logger.info("READ_TIMEOUT_#{property['id']}_#{e}")
          rescue OpenSSL::SSL::SSLError => e
            Rails.logger.info("OPENSSL_ERROR__#{property['id']}_#{e}")
          end
        end
      end
      threads.map(&:join)
      threads = []
      response = nil
      html = nil
      image_urls = []
      Rails.logger.info("FINISHED FOR #{property['id']} AND ZOOPLA ID #{property['zoopla_id']}")
      GC.start(full_mark: true, immediate_sweep: true)
    end
  end

  def self.store_historical_prices
    counter = 0
    glob_counter = 0
    array_of_hashes = []
    redis = Redis.new
    CSV.foreach('/mnt3/flat_transactions.csv',  :encoding => 'ISO-8859-1') do |row|
      price = row[1].to_i
      uuid = row[0]
      date = row[2]
      array_of_hashes.push({ uuid: uuid, price: price, date: date })
      if counter == 10000
        futures = []
        redis.pipelined do
          array_of_hashes.each do |each_hash|
            futures.push(redis.hget('uuid_udprn_map_new', each_hash[:uuid]))
          end
        end
        futures.map(&:value).each_with_index do |value, index|
          array_of_hashes[index][:udprn] = value
        end
        futures = []
         PropertyHistoricalDetail.bulk_insert do |worker|
           array_of_hashes.each do |each_hash|
             worker.add(each_hash)
           end
         end
        counter = 0
        array_of_hashes = []
        p glob_counter
        glob_counter += 1
        next
      end
      counter += 1
    end
  end

  def self.associate_udprn_to_uuids
    redis = Redis.new
    offset = 100
    counter = 0
    loop do
      property_sql = PropertyHistoricalDetail.select([:id, :udprn]).where('id > ?', (counter*offset)).limit(offset).to_sql
      each_counter = 0
      PropertyHistoricalDetail.connection.execute(property_sql).each do |result|
        each_counter += 1
      end
      counter += 1
      break if each_counter == 0
    end
  end

  def self.attach_historical_details_to_udprns
    offset = 1000
    counter = 21013
    client = Elasticsearch::Client.new
    loop do
      property_sql = PropertyHistoricalDetail.select([:id, :udprn, :date, :price]).where.not(udprn: nil).where('id > ?', (counter*offset)).limit(offset).to_sql
      each_counter = 0
      es_addresses_buffer = []
      p "Before sql"

      PropertyHistoricalDetail.connection.execute(property_sql).each do |result|
        each_counter += 1
        date = result['date'].split(' ')[0]
        es_addresses_buffer.push({ update: { _index: 'addresses', _type: 'address', _id: result['udprn'], data: { doc: { last_sale_price: result['price'], last_sale_date: date } } } })
      end
      p "After sql"
      client.bulk body: es_addresses_buffer
      counter += 1
      p counter
      break if each_counter == 0
    end
  end

  def self.extract_uuids
    scroll_id = 'c2Nhbjs1OzQ2OnJaRjRpZWFqUVh5a0pXeGJLaVpEUUE7NDg6clpGNGllYWpRWHlrSld4YktpWkRRQTs0OTpyWkY0aWVhalFYeWtKV3hiS2laRFFBOzUwOnJaRjRpZWFqUVh5a0pXeGJLaVpEUUE7NDc6clpGNGllYWpRWHlrSld4YktpWkRRQTsxO3RvdGFsX2hpdHM6Mjk2ODgzNDM7'
    get_url = 'http://localhost:9200/_search/scroll' + "?scroll_id=#{scroll_id}"
    loop do
      response = Net::HTTP.get(URI.parse(get_url))
      udprns = JSON.parse(response)["hits"]["hits"].map { |t| [ t['_source']['udprn'], t['_source']['post_town'] ] }
      break if udprns.length == 0
      udprns.each do |udprn|
        File.open('random_uuids.log', 'a'){ |t| t.puts("#{udprn[0]}|#{udprn[1]}") }
      end
    end
  end

  def self.post_url_new(query = {}, index_name='property_details', type_name='property_detail')
    uri = URI.parse(URI.encode("http://localhost:9200/_search/scroll"))
    query = (query == {}) ? "" : query.to_json
    http = Net::HTTP.new(uri.host, uri.port)
    result = http.post(uri,query)
    body = result.body
    status = result.code
    return body,status
  end

  def self.extract_daily_uuids
    uuids = []
    counter = 0
    glob_counter = 0
    File.foreach('random_uuids_new.log').each do |line|
      uuids << line.to_i
      counter += 1
      if counter > 25000
        file_name = '/mnt3/random_uuids_' + glob_counter.to_s + '.log'
        file = File.open(file_name, 'w')
        uuids.map { |t| file.puts(t) }
        file.close
        counter = 0
        uuids = []
        glob_counter += 1
        p "#{glob_counter} PASS"
      end
    end
  end

  def self.update_lat_long
    conn = ActiveRecord::Base.connection
    res = Agent.connection.execute("SELECT id, stored_response ->> 'latitude' as latitude, stored_response ->> 'longitude' as longitude FROM agents_branches_crawled_properties")
    res.each do |property|
      id = property['id']
      latitude = property['latitude'].to_f
      longitude = property['longitude'].to_f
      conn.execute("UPDATE agents_branches_crawled_properties SET latitude = #{latitude}, longitude = #{longitude} WHERE id = #{id} ")
    end;nil
  end

  def self.crawl_additional_details(start_index=0, end_index=0)
    KLASS.connection.execute(KLASS.where.not(zoopla_id: nil).where(additional_details: nil).where("id>?", start_index).where("id<?", end_index).select([:id, :zoopla_id]).order('id asc').to_sql).each do |property|
      url = "http://www.zoopla.co.uk/for-sale/details/#{property['zoopla_id']}"
      response = generic_url_processor(url)
      if response
        html = Nokogiri::HTML(response)
        arr_arr_tags = []
        details_map = {}
        script_node = html.css("head script").select{|t| t.text.index("googletag.pubads().setTargeting")}.last
        if script_node
          details_arr = script_node.text.scan(/googletag.pubads\(\).setTargeting\((.+?)\);/)
          value = nil
          details_arr.each do |each_arr_tag|
            values = each_arr_tag[0].split(',')
            key = values[0].gsub("\"","")
            key = key.strip
            value = values[1].gsub("'", "''")
            value = value.gsub("\"", '')
            value = value.strip
            details_map[key] = value
          end
          # begin
            KLASS.connection.execute("UPDATE agents_branches_crawled_properties SET additional_details = '#{details_map.to_json}' WHERE id = #{property['id']} ")
            Rails.logger.info("FINISHED CRAWLING ADDITIONAL DETAILS FOR #{property['id']}")
          # rescue Exception => err
            # binding.pry
            # Rails.logger.info("ERROR IN CRAWLING ADDITIONAL DETAILS FOR #{property['id']}")
            # p 'hello'
          # end
        end
        response = nil
        value = nil
        details_map = nil
        arr_arr_tags = nil
        values = nil
        url = nil
        details_arr = nil
        script_node = nil
      end
      GC.start(full_mark: true, immediate_sweep: true)
    end
  end

end


