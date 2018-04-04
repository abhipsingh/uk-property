if Rails.env == 'production'
  require 'prometheus_exporter/client'
  client = PrometheusExporter::Client.new(host: 'localhost', port: 3002)
  Rails.configuration.request_latencies  = client.register(:gauge, :request_latencies, 'a gauge of request lantencies')
  Rails.configuration.api_server_response_time  = client.register(:summary, :api_server_response_time, 'a histogram of request lantencies')
  Rails.configuration.failed_request_counter= client.register(:counter, :failed_requests, 'a flag to indicate failed requests')
  Rails.configuration.user_admin_panel_key = client.register(:counter, :user_admin_panel_key, 'To see the stats about user admin panel')
end

