class FailureAlertWorker
  include Sidekiq::Worker
  sidekiq_options :retry => false # job will be discarded immediately if failed

  def perform(exception, route)
    Rails.configuration.failed_request_counter.observe(1, { route: route, exception: exception })
    sleep 5
    Rails.configuration.failed_request_counter.observe(1, { route: route, exception: exception })
  end
end

