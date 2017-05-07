require 'net/http'
require 'nokogiri'
require 'open-uri'
require 'csv'

module OnTheMarketRentCrawler
  CONN = ActiveRecord::Base.connection
  KLASS = Agents::Branches::CrawledProperty
  URL_PREFIX = 'https://www.onthemarket.com'
  UK_LOCATIONS_LIST = ['england', 'scotland', 'wales']
  
  def self.generic_url_processor(url,limit = 10)
    return nil if url == 'https://www.onthemarket.com'
    begin
      uri = URI.parse(url)
    rescue URI::InvalidURIError
      return nil
    end
    body = nil
    Rails.logger.info("CRAWLING #{url}|____#{limit}")
    if uri.class == URI::HTTP || uri.class == URI::HTTPS
      response = nil
      begin
        Timeout::timeout(5) {
          response = Net::HTTP.get_response(uri)
        }
        case response.code.to_i
        when 200 then body = response.body
        when 301 then 
          Rails.logger.info("REDIRECTION HAPPENING #{response['location']}")
          body = generic_url_processor(URL_PREFIX + response['location'], limit -1)
        else
          Rails.logger.info("FAILURE_TO_CRAWL_#{url}_#{response.code}")
        end
      rescue
        body = generic_url_processor(url, limit - 1)
      end
    end
    body
  end


  def self.store_all_agent_urls
    characters = ('y'..'z').to_a
    characters.each do |each_char|
      url = URL_PREFIX + '/agents/directory/' + each_char + '/'
      response = generic_url_processor(url)
      if response
        html = Nokogiri::HTML(response)
        hrefs = html.css('li.agent-company').css('li').css('a').map { |e| e['href'] }
        File.write("#{each_char}_agent_list", hrefs.to_json)
      end
    end
  end

  def self.crawl_localities
    UK_LOCATIONS_LIST.each do |locality|
      url = URL_PREFIX + '/property/' + locality + '/'
      response = generic_url_processor(url)
      if response
        html = Nokogiri::HTML(response)
        child_node = html.css('h2#top-children').first
        crawlable_locality_hrefs = child_node.parent.css('ul.list-of-links li a').map{|t| t['href']}
        crawlable_localities = crawlable_locality_hrefs.map { |e| e.split('/').last }
        File.write("#{locality}_localities.txt",crawlable_localities.to_json)
      end
    end
  end

  def self.crawl_properties_from_localities(property_type='to-rent')
    locality_cond = page_cond = true
    if_locality = 'london-region'
    if_page = 39
    UK_LOCATIONS_LIST.each do |locality|
      localities_json = File.read("#{locality}_localities.txt")
      localities = JSON.parse(localities_json)
      localities.each do |each_locality|
        page = 0
        loop do
          url = URL_PREFIX + "/#{property_type}/property/" + each_locality + "/?page=#{page}&view=grid"
          p "PAGE #{page} AND LOCALITY #{each_locality}"
          if each_locality == if_locality
            locality_cond = true
          end

          if locality_cond && page == if_page
            page_cond = true
          end

          if locality_cond && page_cond
            response = generic_url_processor(url)
            html = Nokogiri::HTML(response)
            property_links = html.css('div.property-image a').map { |e| e['href'] }
            if property_links.empty?
              break
            else
              File.open('buy_property_links.txt', 'a'){ |t| t.puts property_links.to_json }
            end
            page = page + 1
          elsif locality_cond
            page = page + 1
          else
            break
          end

        end
      end
    end
  end

  def self.crawl_property(id, property_type='rent')
    url = 'https://www.onthemarket.com/details/' + id.to_s + '/'
    response = generic_url_processor(url)
    html = Nokogiri::HTML(response)
    price = html.css('div.details-heading-top p.price span.price-data').text
    description = html.css('div.details-heading-top div.details-heading h1').text
    locality = html.css('div.details-heading-top div.details-heading p').last.text rescue nil
    image_urls = html.css('div.images img').map{ |t| t['src'] }
    description_content = html.css('div.description-tabcontent').to_s
    agent_url = html.css('div.agent-details div.panel-content a').map { |e| e['href'] }.first
    coordinate_html = html.css('script').select{|t| t.children.to_s.include?("MEDIA_PREFIX")}.first.children.to_s rescue nil
    if coordinate_html
      start_index = coordinate_html.index("AM.property.location")
      relevant_str = coordinate_html[start_index..coordinate_html.length-1]
      start_of_coord_str = relevant_str.index('{')
      end_of_coord_str = relevant_str.index('}')
      lat_lon_str = relevant_str[start_of_coord_str+1..end_of_coord_str-1]
      lat_lon_parts = lat_lon_str.split(',')
      latitude = eval(lat_lon_parts[1].split(":")[1].strip).to_f
      longitude = eval(lat_lon_parts[0].split(":")[1].strip).to_f
      if property_type == 'rent'
        begin
          Agents::Branches::CrawledProperties::Rent.create(id: id, price: price, description: description, locality: locality, agent_url: agent_url, latitude: latitude, longitude: longitude, image_urls: image_urls)
        rescue ActiveRecord::RecordNotUnique
        end
      else
        floorplan_urls = html.css('div.floorplans-tabcontent img').map{ |t| t['href'] }
        begin
          Agents::Branches::CrawledProperties::Buy.create(id: id, price: price, description: description, locality: locality, agent_url: agent_url, latitude: latitude, longitude: longitude, image_urls: image_urls, floorplan_urls: floorplan_urls)
        rescue ActiveRecord::RecordNotUnique
        end
      end
    end
    price, description, locality, image_urls, description_content, agent_url, coordinate_html, relevant_str, start_of_coord_str, end_of_coord_str, lat_lon_str,lat_lon_parts, latitude, longitude = nil
  end

  def self.crawl_all_rent_properties(suffix)
    File.open("rent_links/rent_links#{suffix}", 'r').each_line do |line|
      urls = Oj.load(line)
      ids = urls.map { |e| e.split('/').last.to_i }
      ids.each do |id|
        unless Agents::Branches::CrawledProperties::Rent.where(id: id).last
          crawl_property(id)
        end
      end
    end
  end

  def self.crawl_all_buy_properties(suffix)
    File.open("buy_links/buy_links#{suffix}", 'r').each_line do |line|
      urls = Oj.load(line)
      ids = urls.map { |e| e.split('/').last.to_i }
      ids.each do |id|
        if Agents::Branches::CrawledProperties::Buy.where(id: id).last.nil?
          crawl_property(id, 'buy')
        end
      end
      GC.start(full_mark: true, immediate_sweep: true)
    end
  end

  def self.crawl_agents_branch(agent_url)
    # p agent_url
    response = generic_url_processor(agent_url)
    if response
      html = Nokogiri::HTML(response)
      agent_image_url = html.css('div.agent-image img').first['src'] rescue nil
      html.css('ul#properties div.property').each do |property_html|
        agent_name = property_html.css('a').first.text
        agent_url = property_html.css('a').first['href']
        #address = property_html.css('p.address').first.text.strip
        #phone = property_html.css('div.agent-telephone span.phone').first.text.strip
        #Agents::Branches::OnTheMarketRent.create(name: agent_name, address: address, phone: phone, image_url: agent_image_url)
        Agents::Branches::OnTheMarketRent.where(name: agent_name).update_all(agent_url: agent_url)
      end
    end
  end

  def self.crawl_agents_branch_details(agent_url)
    # p agent_url
    uri=URI.parse(agent_url)
    if Agents::Branches::OnTheMarketRent.where(agent_url: uri.path).last.nil?
      response = generic_url_processor(agent_url)
      if response
        html = Nokogiri::HTML(response)
        agent_name = html.css('div.panel-header h1').text
        address = html.css('div.panel-header p').text
        phone = html.css('div.agent-phone-link').text.strip
        agent_image_url = html.css('div.agent-details img').first['src']
        Agents::Branches::OnTheMarketRent.create(name: agent_name, address: address, phone: phone, image_url: agent_image_url, agent_url: uri.path)
      end
    end
  end

  def self.crawl_all_agents_branch_of_alphabet(alphabet)
    agent_list = File.read("agents_list/#{alphabet}_agent_list")
    agent_urls = Oj.load(agent_list)
    agent_urls.map { |e| e.split('/').last }
                            .map { |e| URL_PREFIX + '/agent/' + e + '/' }
                            .map { |branch_url| crawl_agents_branch(branch_url) }
    nil
  end

  def self.crawl_all_alphabets_agent
    alphabets = ('a'..'z').to_a
    alphabets.map { |alphabet| crawl_all_agents_branch_of_alphabet(alphabet) }
  end

  def self.crawl_property_images(id)
    Agents::Branches::CrawledProperties::Rent.where("created_at > ?", 5.hours.ago).where(id: id).select([:image_urls]).each do |property|
      property.image_urls.map { |image_url| crawl_image(image_url, id) }
    end
    nil
  end

  def self.crawl_property_images_buy(id)
    Agents::Branches::CrawledProperties::Buy.where(id: id).select([:image_urls]).each do |property|
      property.image_urls.map { |image_url| crawl_image(image_url, id, 'buy-mto-properties') }
    end
    nil
  end

  def self.crawl_image(image_url, id, bucket='rent-mto-properties')
    s3 = Aws::S3::Resource.new
    if image_url
      s3_file_name = "#{id}/#{File.basename(image_url)}"
      file_name = File.basename(image_url)
      file_name = file_name + '_' + id.to_s
      p "#{file_name}_____#{id}"
      begin
        open(image_url,"User-Agent" => "Whatever you want here") {|f|
          File.open(file_name,"wb") do |file|
            file.puts f.read
          end
        }
        obj = s3.bucket(bucket).object(s3_file_name)
        obj.upload_file(file_name, acl: 'public-read')
        File.delete(file_name)
      rescue OpenURI::HTTPError => e
        Rails.logger.info("FAILED_TO_CRAWL_IMAGE_WITH_URL_#{image_url}")
      rescue Errno::ENOENT => e
        Rails.logger.info("FILE_ERROR_#{id}_#{e}")
      rescue URI::InvalidURIError => e
        Rails.logger.info("INVALID_URI_ERROR_#{id}_#{e}")
      rescue Net::ReadTimeout => e
        Rails.logger.info("READ_TIMEOUT_#{id}_#{e}")
      rescue OpenSSL::SSL::SSLError => e
        Rails.logger.info("OPENSSL_ERROR__#{id}_#{e}")
      end
    end
  end

  def self.crawl_all_property_images(from, to)
    ids = Agents::Branches::CrawledProperties::Rent.where("id >= ?", from).where("id <= ?", to).pluck(:id).sort
    ids.each do |id|
      crawl_property_images(id)
    end 
  end

  def self.crawl_rent_images_from_file(filename)
    ids = Oj.load(File.read(filename))
    ids.each do |id|
      crawl_property_images(id)
    end 
  end

  def self.crawl_buy_images_from_file(filename)
    ids = Oj.load(File.read(filename))
    ids.each do |id|
      crawl_property_images_buy(id)
    end 
  end

  def self.crawl_all_agent_logos(from, to)
    ids = Agents::Branches::OnTheMarketRent.where("id >= ?", from).where("id <= ?", to).pluck(:id).sort
    ids.each do |id|
      crawl_agent_logo(id)
    end 
  end

  def self.crawl_agent_logo(id)
    Agents::Branches::OnTheMarketRent.where(id: id).select(:image_url).each do |agent|
      crawl_image(agent.image_url, id, 'rent-mto-agents') 
      GC.start(full_mark: true, immediate_sweep: true)
    end
    nil
  end

	def self.crawl_properties_buy_rent_for_all_localities
    UK_LOCATIONS_LIST.each do |locality|
			crawl_localities_from_seed(locality)
    end
	end

  def self.crawl_localities_from_seed(locality)
    url = URL_PREFIX + '/property/' + locality + '/'
    crawl_localities_recursive(url)
  end

  def self.crawl_localities_recursive(url)
    resp = generic_url_processor(url)
    if resp
      html = Nokogiri::HTML(resp)
      locality_node = html.css('h2#top-children').first
      locality_cond = true
      if url == 'https://www.onthemarket.com//property/east-london/waltham-forest/e4/north-east-london/'
        locality_cond = true
      end
      if locality_node
        parent = locality_node.parent
        locality_hrefs = parent.css('ul.list-of-links li a').map { |e| e['href'] }
        extra_hrefs = html.css('div.expand-text li a').map { |e| e['href'] }
        all_hrefs = locality_hrefs + extra_hrefs
        all_hrefs.map { |href| URL_PREFIX + '/' + href }
                 .map { |url| File.open('localities_hierarchy.txt', 'a') { |t| t.puts url } }
        p "URL_#{url}"
        existing_url = VisitedUrl.where(url: url).last
        if existing_url.nil?
          all_hrefs.map { |href| URL_PREFIX + href }
                   .map { |url| crawl_localities_recursive(url); }
          all_hrefs.map { |href| URL_PREFIX + href }
                   .map { |url| VisitedUrl.create(url: url) }
          VisitedUrl.create(url: url)
        end
      elsif locality_cond
        locality_suffix = url.split('/').last
        existing_locality = VisitedLocality.where(locality: locality_suffix).last
        if existing_locality.nil?
          crawl_properties_for_locality(locality_suffix)
          VisitedLocality.create(locality: locality_suffix)
        end
      end
    end
  end

  def self.crawl_properties_for_locality(locality_suffix)
    ['to-rent', 'for-sale'].each do |service|
      page = 0
      loop do
        url = URL_PREFIX + '/' + service + '/property/' + locality_suffix + "/?page=#{page}&view=grid"
        resp = generic_url_processor(url)
        if resp
          html = Nokogiri::HTML(resp)
          property_links = html.css('div.property-image a').map { |e| e['href'] }
          if property_links.empty?
            break
          else
            File.open("#{service}_property_links.txt", 'a'){ |t| t.puts property_links.to_json }
          end
        else
          break
        end
        page = page + 1
      end
    end
  end

  def self.crawl_postcodes_buy(from, to)
    Agents::Branches::CrawledProperties::Buy.where("id > ?", from).where("id < ?", to).select([:id, :latitude, :longitude]).each do |property|
      latitude = property.latitude
      longitude = property.longitude
      url = "http://api.postcodes.io/postcodes?lon=#{longitude}&lat=#{latitude}"
      res = Net::HTTP.get_response(URI.parse(url))
      if res.code.to_i == 200
        postcode = Oj.load(res.body)['result'].first['postcode'] rescue nil
        Agents::Branches::CrawledProperties::Buy.where(id: property.id).update_all(postcode: postcode) if postcode
        Rails.logger.info("POSTCODE FETCHING FAILED FOR #{property.id}") unless postcode
      end
      p property.id
    end
  end

  def self.crawl_postcodes_rent(from, to)
    Agents::Branches::CrawledProperties::Rent.where("id > ?", from).where("id < ?", to).select([:id, :latitude, :longitude]).each do |property|
      latitude = property.latitude
      longitude = property.longitude
      url = "http://api.postcodes.io/postcodes?lon=#{longitude}&lat=#{latitude}"
      res = Net::HTTP.get_response(URI.parse(url))
      if res.code.to_i == 200
        postcode = Oj.load(res.body)['result'].first['postcode'] rescue nil
        Agents::Branches::CrawledProperties::Rent.where(id: property.id).update_all(postcode: postcode) if postcode
        Rails.logger.info("POSTCODE FETCHING FAILED FOR #{property.id}") unless postcode
      end
      p property.id
    end
  end

end

