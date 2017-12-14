class VendorUpdateWorker

  include Sidekiq::Worker
  sidekiq_options :retry => false # job will be discarded immediately if failed

  def perform(vendor_id)
    search_params = { vendor_id: vendor_id.to_i, limit: 1000 }
    search_params
    api = PropertySearchApi.new(filtered_params: search_params)
    api.apply_filters
    ### TODO: TEMP HARD LIMIT OF 1000. Need to handle exceed maybe for some agent
    api.query[:size] = 1000
    udprns, status = api.fetch_udprns
    if status.to_i == 200
      udprns.each do |udprn|
        update_hash = {}
        PropertyService.attach_vendor_details(vendor_id, update_hash)
        PropertyService.new(udprn).update_details(update_hash)
      end
    end
  end

end

