class BuyerMailer < ApplicationMailer
	
  def tracking_emails(tracking_buyer, details)
    @udprn_address = details['address']
    @last_property_status_type = details['last_property_status_type']
    @new_property_status_type = details['property_status_type']
    @tracking_buyer_name = tracking_buyer['name']
    @beds = details['beds']
    @baths = details['baths']
    @receptions = details['receptions']
    price = details['sale_price']
    price ||= details['current_valuation']
    price ||= details['sale_price']
    @price = price
    @assigned_agent_name = details['assigned_agent_name']
    @assigned_agent_mobile = details['assigned_agent_mobile']
    @assigned_agent_title = details['assigned_agent_title']
    @assigned_agent_email = details['assigned_agent_email']
    @assigned_agent_branch = details['assigned_agent_branch_name']

    @tracking_date = Events::Track.where(id: tracking_buyer['id']).order('type_of_tracking ASC').select(:created_at).first.created_at.to_time
    @unsubscribe_link = "https://api.prophety.co.uk/events/unsubscribe?buyer_id=#{tracking_buyer["id"]}&udprn=#{@details["udprn"]}"
    mail(to: tracking_buyer["email"], subject: "Start Tracking")
  end

  def enquiry_emails(enquiry_buyers, details)
    @udprn_address = details['address']
    @last_property_status_type = details['last_property_status_type']
    @new_property_status_type = details['new_property_status_type']
    enquiry_buyers.each do |enquiry_buyer|
      @enquiry_buyer = enquiry_buyer
      ## TODO - pick this from config
      @unsubscribe_link = "https://api.prophety.co.uk/events/unsubscribe?buyer_id=#{@enquiry_buyer["buyer_id"]}&udprn=#{@details["udprn"]}"
      mail(to: @enquiry_buyer["buyer_email"], subject: "Start Tracking")
    end
  end

  def offer_made_stage_emails(property_buyer, details)
    @udprn_address = details['address']
    event = 'offer_made_stage'
    @property_buyer_name = property_buyer['name']
    @beds = details['beds']
    @baths = details['baths']
    @receptions = details['receptions']
    price = details['sale_price']
    price ||= details['current_valuation']
    price ||= details['sale_price']
    @price = price
    @assigned_agent_name = details['assigned_agent_name']
    @assigned_agent_mobile = details['assigned_agent_mobile']
    @assigned_agent_title = details['assigned_agent_title']
    @assigned_agent_email = details['assigned_agent_email']
    @assigned_agent_branch = details['assigned_agent_branch_name']
    @tracking_date = Events::Track.where(id: property_buyer['id']).order('type_of_tracking ASC').select(:created_at).first.created_at.to_time
    @offer_date = Date.today.to_s
    ### TODO - pick this from config
    @unsubscribe_link = "https://api.prophety.co.uk/events/unsubscribe?buyer_id=#{tracking_buyer["id"]}&udprn=#{@details["udprn"]}"
    mail(to: property_buyer["buyer_email"], subject: "Offer Made")
  end

  def send_email_for_a_matching_property(first_name, last_name, email, details, tracking_date, type_of_tracking, buyer_id, update_hash)
    @first_name = first_name
    @last_name = last_name
    @details = details.with_indifferent_access
    @tracking_date = tracking_date
    @unsubscribe_link = "https://api.prophety.co.uk/events/unsubscribe?buyer_id=#{buyer_id}"
    update_hash = update_hash.with_indifferent_access

    if update_hash['property_status_type'] 
      previous_property_status_type = details['property_status_type']
      new_property_status_type = update_hash['property_status_type']
      @message = "The status of the property located at #{details['address']} has been changed from #{previous_property_status_type} to #{new_property_status_type}"
    elsif update_hash['sold']
      @message = "The property located at #{details['address']} has been sold to a new buyer"
    elsif update_hash['offer_made']
      @message = "The property located at #{details['address']} has just been made a new offer"
    end

    if "#{type_of_tracking}" == 'property_tracking'
      subject = "An update has occured in the property you were tracking"
    else
      tag = nil
      ("#{type_of_tracking}" == 'locality_tracking') ? tag = 'locality' : tag = 'street'
      subject = "An update has occured in the #{tag} you were tracking"
    end
    mail(to: email, subject: subject)
  end

end
