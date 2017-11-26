class VendorService

  attr_accessor :vendor_id

  def initialize(vendor_id)
    @vendor_id = vendor_id
  end

  def send_email_following_agent_lead(agent_id, address)
    agent_attrs = [ :first_name, :last_name, :email, :mobile ]
    agent_details = Agents::Branches::AssignedAgent.fetch_details(agent_attrs, [ agent_id.to_i ])
    vendor_attrs = [ :email, :name ]
    vendor_details = Vendor.fetch_details(vendor_attrs, [ @vendor_id ])
    VendorMailer.agent_lead_expect_visit(vendor_details.first, agent_details.first, address).deliver_now
  end

  def send_email_following_agent_details_submission(agent_id, details)
    agent_attrs = [ :name, :email, :mobile ]
    agent_details = Agents::Branches::AssignedAgent.fetch_details(agent_attrs, [ agent_id.to_i ])
    vendor_attrs = [ :email, :name ]
    vendor_details = Vendor.fetch_details(vendor_attrs, [ @vendor_id ])
    VendorMailer.prepare_report_after_agent_lead_submit(vendor_details.first, agent_details.first, details).deliver_now
  end

  def self.send_email_following_agent_lead(agent_attrs, email)
    VendorMailer.agent_lead_expect_visit(agent_attrs, email).deliver_now
  end

end
