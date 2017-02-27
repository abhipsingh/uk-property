class BuyerMailer < ApplicationMailer
	
  def tracking_emails tracking_buyers, udprn_address, last_property_status_type, new_property_status_type
    @udprn_address = udprn_address
    @last_property_status_type = last_property_status_type
    @new_property_status_type = new_property_status_type
    tracking_buyers.each do |tracking_buyer|
    	@tracking_buyer = tracking_buyer
      mail(to: @tracking_buyer["buyer_email"], subject: "Start Tracking")
    end
  end

  def enquiry_emails enquiry_buyers, udprn_address, last_property_status_type, new_property_status_type
    @udprn_address = udprn_address
    @last_property_status_type = last_property_status_type
    @new_property_status_type = new_property_status_type
    enquiry_buyers.each do |enquiry_buyer|
    	@enquiry_buyer = enquiry_buyer
      mail(to: @enquiry_buyer["buyer_email"], subject: "Start Enquiring")
    end
  end

  def offer_made_stage_emails property_buyers, udprn_address
    @udprn_address = udprn_address
    property_buyers.each do |property_buyer|
      @property_buyer = property_buyer
      mail(to: @property_buyer["buyer_email"], subject: "Offer Made")
    end
  end

end