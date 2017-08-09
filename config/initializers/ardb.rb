Rails.application.ardb_host = ENV['ARDB_HOST']
Rails.application.ardb_port = ENV['ARDB_PORT']
Rails.application.ardb_client = Redis.new(
  host: Rails.application.ardb_host,
  port: Rails.application.ardb_port
)