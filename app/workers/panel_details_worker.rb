class PanelDetailsWorker
  include Sidekiq::Worker
  sidekiq_options :retry => false # job will be discarded immediately if failed
  def self.perform
    User.postcode_area_panel_details_cache
    tomorrow_midnight = Time.parse(Date.tomorrow.to_s + " 00:00:00 UTC")
    PanelDetailsWorker.perform_at(tomorrow_midnight)
  end
end
