require 'net/http'
require 'nokogiri'
require 'open-uri'
require 'csv'


module PbCrawler
  URL_PREFIX = 'https://www.purplebricks.com'

  def self.crawl_prop_details_from_csv(csv_file)
    CSV.foreach(csv_file, :headers => true) do |line|
      url = 'https://www.purplebricks.com' + '/Api/Propertylisting/' + line['Property ID']
      body = OnTheMarketRentCrawler.generic_url_processor(url)
      if body
        response = Oj.load(body)
        PbDetail.create!(id: response['id'].to_i, details: response.except(['id']))
      end
      p "#{line['Property ID']} Crawled"
    end
  end
end
