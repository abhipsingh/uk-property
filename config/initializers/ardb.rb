Rails.configuration.ardb_host = ENV['ARDB_HOST_NAME']
Rails.configuration.ardb_port = ENV['ARDB_PORT_NAME']
Rails.configuration.ardb_client = Redis.new(
  host: Rails.configuration.ardb_host,
  port: Rails.configuration.ardb_port
)