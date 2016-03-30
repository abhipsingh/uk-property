namespace :zoopla_crawl do
  desc "Crawl zoopla agent urls"
  task crawl_agent_info: :environment do
    ZooplaCrawler.perform_agent_crawling
  end

  desc "Crawl zoopla property urls"
  task crawl_property_info: :environment do
    ZooplaCrawler.perform_crawling_sale_properties
  end

  desc "Crawl images and store it in S3"
  task images: :environment do
    ZooplaCrawler.crawl_images
  end

end
