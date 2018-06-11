class SuccessAlertWorker
  include Sidekiq::Worker
  sidekiq_options :retry => false # job will be discarded immediately if failed

  def perform(duration_in_ms, route, status)
  end
end

