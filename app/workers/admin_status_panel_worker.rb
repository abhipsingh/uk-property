class AdminStatusPanelWorker
  include Sidekiq::Worker
  sidekiq_options :retry => false # job will be discarded immediately if failed

  def perform
    AdminStatusPanelWorker.perform_in(24.hours)
    User.postcode_area_panel_details 
  end
end

