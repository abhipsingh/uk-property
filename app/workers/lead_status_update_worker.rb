class LeadStatusUpdateWorker
  include Sidekiq::Worker
  sidekiq_options :retry => false # job will be discarded immediately if failed

  def perform
    ### All leads which were created 7 days ago and which have to be inspected for if the agent completed the mandatory attributes
    ### or not
    leads = Agents::Branches::AssignedAgents::Lead.where.not(agent_id: nil).where('date(updated_at) = ?', 7.days.ago.to_date.to_s)
  
    leads.each do |lead|
      udprn = lead.property_id
      details = PropertyDetails.details[:_source]
      details_completed = details[:details_completed]
     
      ### Check the flag for mandatory details being completed or not
      if details_completed.to_s != 'true'

        ### Disassociate the agent from its properties and enquiries
        update_hash = { agent_id: nil }
        property_service = PropertyService.new(udprn)
        property_service.update_details(update_hash)
        Event.unscope(where: :is_archived).where(udprn: udprn).update_all(agent_id: nil)

        ### Lock the branch so that new leads and quotes are not accessible for 30 days
        branch = lead.agent.branch
        branch.update_attributes(locked: true, locked_date: Date.today)

        ### Create a new lead for local branches
        property_service.create_lead_for_local_branches(branch.district, udprn, lead.vendor_id)

      else
        ### Else we shoot an email to the vendor to confirm about the details


      end

    end

  end
end

