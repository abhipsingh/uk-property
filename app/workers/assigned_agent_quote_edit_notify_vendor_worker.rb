class AssignedAgentQuoteEditNotifyVendorWorker
  include Sidekiq::Worker
  include SesEmailSender
  sidekiq_options :retry => false # job will be discarded immediately if failed

  def perform(property_id, agent_id)
    details = PropertyDetails.details(property_id)[:_source]
    assigned_agent_id = details[:agent_id].to_i
    
    ### Send email only if agent id matches with assigned agent id
    if assigned_agent_id == agent_id.to_i
      vendor_first_name = details[:vendor_first_name]
      vendor_property_address = details[:address]
      agent_first_name = details[:assigned_agent_first_name]
      agent_branch_name = details[:assigned_agent_branch_name]
      vendor_email = details[:vendor_email]
      template_data = { vendor_first_name: vendor_first_name, vendor_property_address: vendor_property_address, agent_first_name: agent_first_name,
                        agent_branch_name: agent_branch_name }
      self.class.send_email(vendor_email, 'assigned_agent_quote_edit_notify_vendor', self.class.to_s, template_data)
    end
  end

end

