class AgentMailer < ApplicationMailer
  def welcome_email(user)
    @user = user
    @url  = 'http://example.com/login'
    mail(to: user.agent_email, subject: "Welcome to Prophety")
  end


  def send_email_on_assigned_agent_change_to_previous_agent(agent, property_details, vendor, reason, time)
    branch = agent.branch
    company = branch.agent
    group = company.group

    @branch_name = branch.name
    @company_name = company.name
    @group_name = group.name
    @agent_image_url = agent.image_url
    @agent_first_name = agent.first_name
    @agent_last_name = agent.last_name
    @agent_title = agent.title
    @agent_mobile = agent.mobile
    @agent_office_number = agent.office_phone_number
    @udprn = property_details['udprn']
    @address = property_details['address']
    @vendor_first_name = vendor.first_name
    @vendor_last_name = vendor.last_name
    @vendor_image_url = vendor.image_url
    @vendor_email = vendor.email
    @vendor_mobile = vendor.mobile
    @reason = reason
    @time = time
    mail(to: agent.email, subject: "Change Agent Request")
  end

  def send_email_on_assigned_agent_change_to_admin(previous_agent, new_agent, property_details, vendor, reason, time)
    previous_branch = previous_agent.branch
    previous_company = previous_branch.agent
    previous_group = previous_company.group

    branch = new_agent.branch
    company = branch.agent
    group = company.group
    @new_branch_name = branch.name
    @new_company_name = company.name
    @new_group_name = group.name

    @previous_branch_name = previous_branch.name
    @previous_company_name = previous_company.name
    @previous_group_name = previous_group.name

    @previous_agent_image_url = previous_agent.image_url
    @previous_agent_first_name = previous_agent.first_name
    @previous_agent_last_name = previous_agent.last_name
    @previous_agent_title = previous_agent.title
    @previous_agent_mobile = previous_agent.mobile
    @previous_agent_office_number = previous_agent.office_phone_number

    @new_agent_image_url = new_agent.image_url
    @new_agent_first_name = new_agent.first_name
    @new_agent_last_name = new_agent.last_name
    @new_agent_title = new_agent.title
    @new_agent_mobile = new_agent.mobile
    @new_agent_office_number = new_agent.office_phone_number

    @udprn = property_details['udprn']
    @address = property_details['address']
    @vendor_first_name = vendor.first_name
    @vendor_last_name = vendor.last_name
    @vendor_image_url = vendor.image_url
    @vendor_email = vendor.email
    @vendor_mobile = vendor.mobile
    @reason = reason
    @time = time
    
    admin_email = 'test@prophety.co.uk'
    mail(to: admin_email, subject: "Change of Agent")
  end

  def send_password_reset_email(email_hash)
    @email = email_hash['email']
    @hash = email_hash['hash']
    @profile = email_hash['profile']
    mail(to: @email, subject: 'Password reset')
  end

end
