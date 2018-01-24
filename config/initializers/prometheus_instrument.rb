if Rails.env == 'production'
  require 'prometheus_exporter/client'
  client = PrometheusExporter::Client.new(host: 'localhost', port: 3002)
  Rails.configuration.request_latencies  = client.register(:gauge, :request_latencies, 'A gauge of request lantencies')
  Rails.configuration.failed_request_counter= client.register(:counter, :failed_requests, 'A flag to indicate failed requests')
end

