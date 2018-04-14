class LeadStatusUpdateWorker
  include Sidekiq::Worker
  sidekiq_options :retry => false # job will be discarded immediately if failed

  def perform
    ### All leads which were created 7 days ago and which have to be inspected for if the agent completed the mandatory attributes
    ### or not
    Rails.logger.info("LeadStatusUpdateWorker_STARTED")
    leads = Agents::Branches::AssignedAgents::Lead.where.not(agent_id: nil).where(owned_property: false).where(expired: false).where('updated_at < ?', Agents::Branches::AssignedAgents::Lead::VERIFICATION_DAY_LIMIT.ago)
    #LeadStatusUpdateWorker.perform_in(10.minutes)

    ### TODO:
    leads = [] 
    leads.each do |lead|
      Rails.logger.info("LeadStatusUpdateWorker__STARTED__#{lead.id}")
      udprn = lead.property_id
      details = PropertyDetails.details(udprn)[:_source]
      percent_completed = details[:percent_completed]
     
      ### Check the flag for mandatory details being completed or not
      if percent_completed.to_i < 100

        agent = lead.agent
        Rails.logger.info("LeadStatusUpdateWorker__LockAgentStarted__#{lead.id}_#{agent.id}")
        ### Disassociate the agent from its properties and enquiries
        update_hash = { agent_id: nil }
        property_service = PropertyService.new(udprn)
        property_service.update_details(update_hash) rescue nil
        Event.unscope(where: :is_archived).where(udprn: udprn).update_all(agent_id: nil)

        ### Lock the agent so that new leads and quotes are not accessible for 30 days
        branch = agent.branch
        agent.update_attributes(locked: true, locked_date: Date.today)
        lead.expired = true
        lead.save!
        Rails.logger.info("LeadStatusUpdateWorker__LockAgentFinished__#{lead.id}_#{agent.id}")

        ### Create a new lead for local branches
        property_service.create_lead_for_local_branches(branch.district, udprn, lead.vendor_id)

      else
        ### Else we shoot an email to the vendor to confirm about the details


      end
      Rails.logger.info("LeadStatusUpdateWorker__FINISHED__#{lead.id}")

    end
    Rails.logger.info("LeadStatusUpdateWorker_FINISHED")


  end
end

