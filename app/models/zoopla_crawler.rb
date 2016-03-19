

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
      Rails.logger.info("FAILURE_TO_CRAWL_#{url}")
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
    Agents::Branch.select([:id, :property_urls]).all.each do |branch|
      branch_suffix = branch.property_urls.split("/").last
      perform_each_branch_crawl(branch_suffix, branch.id)
    end
  end

  def self.perform_each_branch_crawl(branch_suffix, branch_id)
    page_size = 100
    page = 1
    loop do
      url = url_prefix + branch_suffix + "?page_size=#{page_size}&pn=#{page}"
      response = generic_url_processor(url)
      if response
        property_urls = Nokogiri::HTML(response.body).css('div.listing-results-right').css('a').map{|t| t['href']}
        break if property_urls.empty?
        sale_urls = property_urls.select{ |t| t.split("/").second=='for-sale' }
        sale_urls.map { |e| crawl_property(each_sale_url) }
        page += 1
      else
        break
      end
    end
  end

  def self.crawl_property(property_url)
    url = BASE_URL + property_url
    response = generic_url_processor(url)
  end

end


