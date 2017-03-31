require 'net/http'
require 'nokogiri'
require 'open-uri'
require 'csv'

module OnTheMarketRentCrawler
  CONN = ActiveRecord::Base.connection
  KLASS = Agents::Branches::CrawledProperty
  URL_PREFIX = 'https://www.onthemarket.com'
  UK_LOCATIONS_LIST = ['england', 'scotland', 'wales']

  def self.process_agent_url(agent_url, agent_id)
    response = generic_url_processor(agent_url)
    if response
      html = Nokogiri::HTML(response)
      b = html.css("div.agents-results").css("h2").css("a")
      hrefs = b.map{ |t| t['href'] }
      names = b.map{ |t| t.text }
      addresses = html.css("div.agents-results").css("p").css("span").map{ |t| t.text }
      names.each_with_index do |name, index|
        begin
          Agents::Branch.create(name: name, property_urls: hrefs[index], address: addresses[index], agent_id: agent_id)
        rescue Exception => e
          p "#{name}_#{hrefs[index]}_#{addresses[index]}_#{agent_id}"
        end
      end
    end
  end

  def self.generic_url_processor(url,limit = 10)
    return nil if url == 'https://www.onthemarket.com'
    uri = URI.parse(url)
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
          body = generic_url_processor(response['location'], limit -1)
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

  def self.crawl_properties_from_localities
    locality_cond, page_cond = false
    if_locality = 'london-region'
    if_page = 39
    UK_LOCATIONS_LIST.each do |locality|
      localities_json = File.read("#{locality}_localities.txt")
      localities = JSON.parse(localities_json)
      localities.each do |each_locality|
        page = 0
        loop do
          url = URL_PREFIX + '/to-rent/property/' + each_locality + "/?page=#{page}&view=grid"
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
              File.open('property_links.txt', 'a'){ |t| t.puts property_links.to_json }
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

  def self.crawl_property(id)
    url = 'https://www.onthemarket.com/details/' + id.to_s + '/'
    response = generic_url_processor(url)
    html = Nokogiri::HTML(response)
    price = html.css('div.details-heading-top p.price span.price-data').text
    description = html.css('div.details-heading-top div.details-heading h1').text
    locality = html.css('div.details-heading-top div.details-heading p').last.text
    image_urls = html.css('div.images img').map{ |t| t['src'] }
    description_content = html.css('div.description-tabcontent').to_s
    agent_url = html.css('div.agent-details div.panel-content a').map { |e| e['href'] }.first
    coordinate_html = html.css('script').select{|t| t.children.to_s.include?("MEDIA_PREFIX")}.first.children.to_s
    start_index = coordinate_html.index("AM.property.location")
    relevant_str = coordinate_html[start_index..coordinate_html.length-1]
    start_of_coord_str = relevant_str.index('{')
    end_of_coord_str = relevant_str.index('}')
    lat_lon_str = relevant_str[start_of_coord_str+1..end_of_coord_str-1]
    lat_lon_parts = lat_lon_str.split(',')
    latitude = eval(lat_lon_parts[1].split(":")[1].strip).to_f
    longitude = eval(lat_lon_parts[0].split(":")[1].strip).to_f
    Agents::Branches::CrawledProperties::Rent.create(id: id, price: price, description: description, locality: locality, agent_url: agent_url, latitude: latitude, longitude: longitude)
    price, description, locality, image_urls, description_content, agent_url, coordinate_html, relevant_str, start_of_coord_str, end_of_coord_str, lat_lon_str,lat_lon_parts, latitude, longitude = nil
  end

  def self.crawl_all_properties
    File.open('property_links.txt', 'r').each_line do |line|
      urls = Oj.load(line)
      ids = urls.map { |e| e.split('/').last.to_i }
      ids.each do |id|
        unless Agents::Branches::CrawledProperties::Rent.where(id: id).last
          crawl_property(id)
          binding.pry
        end
      end
      GC.start(full_mark: true, immediate_sweep: true)
    end
  end

end



