class PanelDetailsWorker
  include Sidekiq::Worker
  sidekiq_options :retry => false # job will be discarded immediately if failed
  def perform
    User.postcode_area_panel_details_cache
  end
end
