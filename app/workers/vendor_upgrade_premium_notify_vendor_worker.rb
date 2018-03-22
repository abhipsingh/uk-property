class VendorUpgradePremiumNotifyVendorWorker
  include SesEmailSender
  include Sidekiq::Worker

  def perform(vendor_id)
    vendor = Vendor.find(vendor_id)
    vendor_first_name = vendor.first_name
    vendor_email = vendor.email
    template_data = { vendor_first_name: vendor_first_name }
    self.class.send_email(vendor_email, 'vendor_upgrade_premium_notify_vendor', self.class.to_s, template_data)
  end

end

