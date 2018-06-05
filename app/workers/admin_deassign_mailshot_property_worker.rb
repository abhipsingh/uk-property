class AdminDeassignMailshotPropertyWorker
  include Sidekiq::Worker
  sidekiq_options :retry => false # job will be discarded immediately if failed

  def perform
    ### List all preassigned properties which have not been registered
    ### by the vendor and have exceeded the limit of 1 months
    AddressDistrictVendor.where(vendor_registered: false).where("expiry_date < ?", Date.today).update_all(expired: true)
  end
end

