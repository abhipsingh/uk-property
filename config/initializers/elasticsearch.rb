Rails.configuration.remote_es_url = "http://#{ENV['ELASTICSEARCH_HOST']}:9200"
Rails.configuration.remote_es_host = ENV['ELASTICSEARCH_HOST']
Rails.configuration.local_es_url = 'http://127.0.0.1:9200'
