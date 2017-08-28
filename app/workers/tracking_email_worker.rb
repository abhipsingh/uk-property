class TrackingEmailWorker
  include Sidekiq::Worker

  def perform(params_hash)
    sleep 8
    p 'hello'
  end
end

