Rails.configuration.remote_es_url = "http://#{ENV['ELASTICSEARCH_HOST']}:9200"
Rails.configuration.remote_es_host = ENV['ELASTICSEARCH_HOST']
Rails.configuration.local_es_url = 'http://127.0.0.1:9200'
Rails.configuration.address_index_name = ENV['ADDRESS_INDEX_NAME']
Rails.configuration.address_type_name = ENV['ADDRESS_TYPE_NAME']
Rails.configuration.location_index_name = ENV['LOCATIONS_INDEX_NAME']
Rails.configuration.location_type_name = ENV['LOCATIONS_TYPE_NAME']
