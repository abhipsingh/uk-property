class VendorMailer < ApplicationMailer
  def welcome_email(user)
    @user = user
    ### TODO: Conditionally change a link depending on whether the vendor has already registered or not
    ### Pass a flag that a vendor is already registered
    vendor_flag = Vendor.where(email: @user.vendor_email).last.nil?
    @link = "http://sleepy-mountain-35147.herokuapp.com/auth?verification_hash=#{@user.verification_hash}&udprn=#{@user.email_udprn}&email=#{@user.vendor_email}&vendor_present=#{vendor_flag}&user_type=Vendor"
    mail(to: @user.vendor_email, subject: "Welcome to Prophety #{@user.vendor_email}")
  end

  def welcome_email_from_a_friend(user)
    @user = user
    vendor_flag = Vendor.where(email: @user.vendor_email).last.nil?
    @link = "http://sleepy-mountain-35147.herokuapp.com/auth?verification_hash=#{@user.verification_hash}&udprn=#{@user.email_udprn}&email=#{@user.vendor_email}&vendor_present=#{vendor_flag}&user_type=Vendor"
    mail(to: @user.vendor_email, subject: "Welcome to Prophety #{@user.vendor_email}")
  end

  def welcome_email_from_a_renter(user)
    @user = user
    vendor_flag = Vendor.where(email: @user.vendor_email).last.nil?
    @link = "http://sleepy-mountain-35147.herokuapp.com/auth?verification_hash=#{@user.verification_hash}&udprn=#{@user.email_udprn}&email=#{@user.vendor_email}&vendor_present=#{vendor_flag}&user_type=Vendor"
    mail(to: @user.vendor_email, subject: "Welcome to Prophety #{@user.vendor_email}")
  end

  def signup_email(hash)
    @email = hash[:email]
    @hash = @hash
    @link = hash[:link]
    mail(to: @email, subject: "Vendor Registration #{@email}")
  end

  def agent_lead_expect_visit(vendor, agent, address)
    @agent_name = agent.first_name.to_s + ' ' + agent.last_name.to_s
    @agent_email = agent.email
    @agent_mobile = agent.mobile
    @vendor_name = vendor.name
    subject = 'An agent has claimed the lead of your property located at ' + address.to_s
    mail(to: vendor.email, subject: subject)
  end

  def agent_lead_expect_visit_manual(agent_attrs, vendor_email)
    @agent_name = agent_attrs[:name]
    @agent_email = agent_attrs[:email]
    @agent_phone = agent_attrs[:office]
    @agent_mobile = agent_attrs[:mobile]
    @agent_title = agent_attrs[:title]
    @agent_company = agent_attrs[:company_name]
    @branch_address = agent_attrs[:branch_address]
    @address = agent_attrs[:address]
    @hash_link = agent_attrs[:hash_link]
    @vendor_email = vendor_email
    @udprn = agent_attrs[:udprn]
    @hash_url = "http://sleepy-mountain-35147.herokuapp.com/auth?verification_hash=#{@hash_link}&udprn=#{@udprn}&email=#{@vendor_email}&user_type=Vendor&vendor_present=true"
    subject = 'An agent has claimed the lead of your property located at ' + @address
    mail(to: vendor_email, subject: subject)
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

