class GoogleStViewImage < ActiveRecord::Base
  def self.crawl_st_view_images
    udprns = []
    count = 0
    File.open('/mnt3/royal.csv', 'r').each_line do |line|
      udprn = line.strip.scrub.split(',')[-4].to_i
      udprns.push(udprn)
      if udprns.length == 1000
        bulk_response = PropertyService.bulk_details(udprns) 
        bulk_response.each do |detail|
          st_view_address = PropertyDetails.google_st_view_address(detail)              
          detail[:street_view_address] = st_view_address
        end
        GoogleStViewImage.bulk_insert(:udprn, :address, :crawled) do |worker|
          bulk_response.each do |detail|
            worker.add [detail[:udprn], detail[:street_view_address], detail[:crawled]]
          end
        end
        udprns = []
        p "count #{count} completed"
        count += 1
      end
    end
  end
end
