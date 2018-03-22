class AgentVendorEnquiryNotifyWorker
  include SesEmailSender
  include Sidekiq::Worker
  sidekiq_options :retry => false # job will be discarded immediately if failed

  def perform(property_id)
    details = PropertyDetails.details(property_id)[:_source]
    agent_first_name = details[:assigned_agent_first_name]
    agent_email = details[:assigned_agent_email]
    vendor_first_name = details[:vendor_first_name]
    vendor_email = details[:vendor_email]
    address = details[:address]

    if vendor_first_name && vendor_email
      destination_addrs = []
      template_data = { vendor_first_name: vendor_first_name, vendor_property_address: address }
      self.class.send_email(vendor_email, 'vendor_enquiry_notify', self.class.to_s, template_data)
    end

    if agent_first_name && agent_email
      destination_addrs = []
      template_data = { agent_first_name: agent_first_name, vendor_property_address: address }
      self.class.send_email(vendor_email, 'agent_enquiry_notify', self.class.to_s, template_data)
    end

  end

end

