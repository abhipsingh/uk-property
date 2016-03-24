

require 'net/http'
require 'nokogiri'

module ZooplaCrawler
  CHARACTERS = (14...36).map{ |i| i.to_s 36}


  URL_PREFIX = 'http://www.zoopla.co.uk/find-agents/estate-agents/directory/'
  BASE_URL = 'http://www.zoopla.co.uk/'

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

  def self.generic_url_processor(url)
    uri = URI.parse(url)
    response = Net::HTTP.get_response(uri)
    if response.code.to_i == 200
      return response.body
    else
      Rails.logger.info("FAILURE_TO_CRAWL_#{url}_#{response.code}")
      return nil
    end
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
          agent = Agent.create(name: name, branches_url: links[index])
          ids.push(agent.id)
        end

        crawlable_urls = links.map { |e|  BASE_URL + e }
        crawlable_urls.each_with_index do |agent_url, index|
          p "CRAWLED URLS #{agent_url}"
          process_agent_url(agent_url, ids[index])
        end
      end
    end
  end

  def self.perform_crawling_sale_properties
    url_prefix = "http://www.zoopla.co.uk/for-sale/branch/"
    p 'started'
    Agents::Branch.select([:id, :property_urls]).find_each do |branch|
      branch_suffix = branch.property_urls.split("/").last
      p "CRAWLED_Strted#{branch.id}"
      perform_each_branch_crawl(branch_suffix, branch.id)
      p "CRAWLED_ended#{branch.id}"
    end
  end

  def self.perform_each_branch_crawl(branch_suffix, branch_id)
    page_size = 100
    url_prefix = "http://www.zoopla.co.uk/for-sale/branch/"
    page = 1
    loop do
      url = url_prefix + branch_suffix + "/?page_size=#{page_size}&pn=#{page}"
      response = generic_url_processor(url)
      if response
        property_urls = Nokogiri::HTML(response).css('div.listing-results-right').css('a').map{|t| t['href']}
        property_urls = property_urls.uniq
        break if property_urls.empty?
        sale_urls = property_urls.select{ |t| t.split("/").second=='for-sale' }
        sale_urls.map { |each_sale_url| crawl_property(each_sale_url, branch_id) }
        page += 1
      else
        break
      end
    end
  end

  def self.crawl_property(property_url, branch_id)
    url = BASE_URL + property_url
    response = generic_url_processor(url)
    stored_response = {}
    if response
      html = Nokogiri::HTML(response)
      html.css('script').remove
      html.css('style').remove
      title = html.css('div#listing-details').css('h2')[0].text rescue nil
      address = html.css('div.listing-details-address').css('h2').text rescue nil
      street_address = html.css('div.listing-details-address').css('meta')[0]['content'] rescue nil
      address_locality = html.css('div.listing-details-address').css('meta')[1]['content'] rescue nil
      address_region = html.css('div.listing-details-address').css('meta')[2]['content'] rescue nil
      latitude = html.css('meta[itemprop="latitude"]')[0]['content'].to_f rescue nil
      longitude = html.css('meta[itemprop="longitude"]')[0]['content'].to_f rescue nil
      beds = html.css('div.listing-details-attr').css('span.num-beds')[0].text.to_i rescue nil
      baths = html.css('div.listing-details-attr').css('span.num-baths')[0].text.to_i rescue nil
      receptions = html.css('div.listing-details-attr').css('span.num-reception')[0].text.to_i rescue nil
      images_original_prefix = html.css('ul#images_original').css('a')[0]['href'] rescue nil
      original_images_url = BASE_URL + images_original_prefix.to_s
      images_response = generic_url_processor(original_images_url)
      image_urls = []
      features = html.css('div#listing-details').css('h3').map{|t| t.parent}.first.css('li').map{|t| t.text} rescue []
      description = html.css('div#listing-details').css('h3').map{|t| t.parent}.second.css('div.top').text.strip rescue ''
      agent_logo = html.css('img.agent_logo')[0]['src'] rescue nil
      if images_response
        images_html = Nokogiri::HTML(images_response)
        image_urls = images_html.css('a').css('img').map{ |t| t['src'] } rescue []
      end
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
      stored_response[:image_urls] = image_urls
      stored_response[:description] = description
      stored_response[:features] = features
      stored_response[:agent_logo] = agent_logo
      # p stored_response
      res = nil
      if title && address && latitude && longitude
        res = Agents::Branches::CrawledProperty.create(stored_response: stored_response, html: nil, branch_id: branch_id, latitude: latitude, longitude: longitude) rescue nil
      end
      Rails.logger.info("CRAWLING_FAILED_FOR_#{branch_id}_#{url}") if res.nil?
    end
  end


end


