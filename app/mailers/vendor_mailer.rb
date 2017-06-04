class VendorMailer < ApplicationMailer
  def welcome_email(user)
    @user = user
    mail(to: @user.vendor_email, subject: "Welcome to Prophety #{@user.vendor_email}")
  end

  def signup_email(hash)
    @email = hash[:email]
    @hash = @hash
    @link = hash[:link]
    mail(to: @email, subject: "Vendor Registration #{@email}")
  end

  def agent_lead_expect_visit(vendor, agent, address)
    @agent_name = agent.name
    @agent_email = agent.email
    @agent_mobile = agent.mobile
    @vendor_name = vendor.name
    subject = 'An agent has claimed the lead of your property located at ' + address.to_s
    mail(to: vendor.email, subject: subject)
  end

  def prepare_report_after_agent_lead_submit(vendor, agent, property_details)
    @agent_name = agent.name
    @agent_email = agent.email
    @agent_mobile = agent.mobile
    @property_details = property_details
    @vendor_name = vendor.name
    subject = 'Agent has submitted the following details of your property'
    mail(to: vendor.email, subject: subject)
  end  
end
