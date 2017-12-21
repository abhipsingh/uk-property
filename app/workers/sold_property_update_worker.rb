class SoldPropertyUpdateWorker
  include Sidekiq::Worker
  sidekiq_options :retry => false # job will be discarded immediately if failed

  def perform
    sold_properties = SoldProperty.where('completion_date = ?', Date.today)
    sold_properties.each do |sold_property|
      udprn = sold_property.udprn
      details = PropertyDetails.details(udprn)[:_source]
      buyer_id = sold_property.buyer_id
      new_vendor_id = PropertyBuyer.find(buyer_id).vendor_id

      ### Update the property details
      update_hash = { property_status_type: nil, vendor_id: new_vendor_id , sold: true, claimed_on: Time.now.to_s, claimed_by: 'Vendor' }

      ### Create a lead for local agents if a new property is sold
      if details[:is_developer].to_s == 'true'
        update_hash[:agent_id] = nil
        property_service = PropertyService.new(property_id)
        property_service.attach_vendor_to_property(new_vendor_id.to_i)
        response = property_service.update_details(update_hash)
      else
        response = PropertyService.new(property_id).update_details(update_hash)
      end
  
      ### Archive the enquiries that were received for this property
      Event.where(udprn: property_id).where(is_archived: false).update_all(is_archived: true)
    end
  end

end

