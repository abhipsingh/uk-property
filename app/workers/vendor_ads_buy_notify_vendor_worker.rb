class VendorAdsBuyNotifyVendorWorker
  include SesEmailSender
  include Sidekiq::Worker

  def perform(property_id)
    details = PropertyDetails.details(property_id)[:_source]
    vendor_email = details[:vendor_email]
    vendor_property_address = details[:address]
    template_data = { vendor_property_address: vendor_property_address }
    self.class.send_email(vendor_email, 'vendor_ads_buy_notify_vendor', self.class.to_s, template_data)
  end

end

