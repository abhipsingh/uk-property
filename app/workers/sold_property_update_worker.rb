class SoldPropertyUpdateWorker
  include Sidekiq::Worker
  sidekiq_options :retry => false # job will be discarded immediately if failed

  def perform
    Rails.logger.info("SoldPropertyUpdateWorker__STARTED")
    sold_properties = SoldProperty.where('created_at <= ?', Date.yesterday).where(status: false)
    sold_properties.each do |sold_property|
      Rails.logger.info("SoldPropertyUpdateWorker_PROCESSING_STARTED_#{sold_property.id}")
      udprn = sold_property.udprn
      details = PropertyDetails.details(udprn)[:_source]
      buyer_id = sold_property.buyer_id
      new_vendor_id = PropertyBuyer.find(buyer_id).vendor_id

      sale_price = { price: sold_property.sale_price, date: sold_property.completion_date.to_s }
      last_sale_price = sold_property.sale_price
      sale_prices ||= details[:sale_prices] || []
      sale_prices.push(sale_price)

      ### Update the property details
      update_hash = { 
                      property_status_type: 'Red',
                      vendor_id: new_vendor_id,
                      sold: true,
                      claimed_on: Time.now.to_s,
                      claimed_by: 'Vendor',
                      sale_price: nil,
                      sale_price_type: nil,
                      price: nil,
                      sale_prices: sale_prices,
                      last_sale_price: last_sale_price
                    }

      ### Create a lead for local agents if a new property is sold
      if details[:is_developer].to_s == 'true'
        update_hash[:agent_id] = nil
        property_service = PropertyService.new(udprn)
        property_service.attach_vendor_to_property(new_vendor_id.to_i)
        updated_details, status = property_service.update_details(update_hash)
      else
        updated_details, status = PropertyService.new(udprn).update_details(update_hash)
      end
      
      ### Update the sold property's status to true
      sold_property.status = true
      sold_property.save!

      ### Archive the enquiries that were received for this property
      Event.where(udprn: udprn).where(is_archived: false).update_all(is_archived: true)

      ### Also archive the fresh property stats and enquiries
      Events::ArchivedStat.new(udprn: udprn.to_i).transfer_from_unarchived_stats

      ### Send emails to tracking buyers
      PropertyService.send_tracking_email_to_tracking_buyers({ sold: true}, updated_details)

      ### Ending of processing of sold property
      Rails.logger.info("SoldPropertyUpdateWorker_PROCESSING_FINISHED_#{sold_property.id}")
    end
    Rails.logger.info("SoldPropertyUpdateWorker__FINISHED")
  end

end

