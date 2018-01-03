class SoldPropertyUpdateWorker
  include Sidekiq::Worker
  sidekiq_options :retry => false # job will be discarded immediately if failed

  def perform
    SoldPropertyUpdateWorker.perform_in(1.day.from_now)
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
        property_service = PropertyService.new(udprn)
        property_service.attach_vendor_to_property(new_vendor_id.to_i)
        response = property_service.update_details(update_hash)
      else
        response = PropertyService.new(udprn).update_details(update_hash)
      end
  
      ### Archive the enquiries that were received for this property
      Event.where(udprn: udprn).where(is_archived: false).update_all(is_archived: true)

      ### Also archive the fresh property stats and enquiries
      Events::ArchivedStat.new(udprn: udprn.to_i).transfer_from_unarchived_stats
    end
  end

end

