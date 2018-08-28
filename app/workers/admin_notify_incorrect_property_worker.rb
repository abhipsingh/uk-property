class AdminNotifyIncorrectPropertyWorker
  include Sidekiq::Worker
  sidekiq_options :retry => false # job will be discarded immediately if failed

  def perform
    search_params = { exists: 'agent_id', results_per_page: 1000 }
    page = 1
    improper_udprns = []
    loop do
      search_params[:p] = page 
      api = PropertySearchApi.new(filtered_params: search_params)
      api.modify_filtered_params
      api.apply_filters
      udprns, status = api.fetch_udprns
      udprns = udprns.map(&:to_i)
      if status.to_i == 200
        improper_udprns = []
        bulk_details = PropertyService.bulk_details(udprns)
        bulk_details.each_with_index do |detail, index|
          agent_id = detail[:agent_id]
          udprn = detail[:udprn].to_i
          udprns = Event.where(agent_id: agent_id).pluck(:udprn)

          if udprns.count > 1 || (udprns.count == 1 && udprns.first != udprn)
            list_of_impossible_udprns = (udprns - [udprn])
            improper_udprns.push(list_of_impossible_udprns)
          end

        end
        
        ### Send an email if inconsistencies are found
        if improper_udprns.length > 0
          improper_bulk_details = PropertyService.bulk_details(improper_udprns)
          AdminMailer.notify_incorrect_properties(improper_bulk_details).deliver_now
        end
      end
      page += 1
      break if udprns.count == 0
    end
  end
end

