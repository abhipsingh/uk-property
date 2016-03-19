namespace :zoopla_crawl do
  desc "Crawl zoopla agent urls"
  task crawl_agent_info: :environment do
    ZooplaCrawler.perform_agent_crawling
  end

end
