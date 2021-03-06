Rails.configuration.ardb_host = ENV['ARDB_HOST_NAME']
Rails.configuration.ardb_port = ENV['ARDB_PORT_NAME']
Rails.configuration.ardb_client = Redis.new(
  host: Rails.configuration.ardb_host,
  port: Rails.configuration.ardb_port,
  db: ENV['ARDB_DB_NO'],
  timeout: 600
)

Rails.configuration.ardb_client_rate_limit = Redis.new(
  host: Rails.configuration.ardb_host,
  port: Rails.configuration.ardb_port,
  db: ENV['ARDB_DB_RATE_LIMIT'],
  timeout: 600
)

Rails.configuration.fr_db = Redis.new(
  host: Rails.configuration.ardb_host,
  port: Rails.configuration.ardb_port,
  db: ENV['FR_DATA_ARDB_DB_NO'],
  timeout: 600
)

