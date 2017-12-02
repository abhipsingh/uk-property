class AgentUpdateWorker
  include Sidekiq::Worker
  sidekiq_options :retry => false # job will be discarded immediately if failed

  def perform(agent_id)
    search_params = { agent_id: agent_id.to_i, limit: 1000 }
    search_params
    api = PropertySearchApi.new(filtered_params: search_params)
    api.apply_filters
    ### TODO: TEMP HARD LIMIT OF 1000. Need to handle exceed maybe for some agent
    api.query[:size] = 1000
    udprns, status = api.fetch_udprns
    if status.to_i == 200
      udprns.each do |udprn|
        update_hash = {}
        PropertyDetails.add_agent_details(update_hash, agent_id)
        PropertyService.new(udprn).update_details(update_hash)
      end
    end
  end
end

