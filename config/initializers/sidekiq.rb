Sidekiq.configure_server do |config|
  config.redis = { url: 'redis://localhost:16379/sidekiq_main_app', network_timeout: 5, namespace: 'sidekiq_main_app' }
end

Sidekiq.configure_client do |config|
  config.redis = { url: 'redis://localhost:16379/sidekiq_main_app', network_timeout: 5,  namespace: 'sidekiq_main_app' }
end
