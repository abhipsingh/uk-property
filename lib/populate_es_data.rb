require 'oj'
require 'net/http'

class PopulateEsData
  def self.setup
    addresses = File.read("#{Rails.root}/addresses.json")
    locations = File.read("#{Rails.root}/suggest.txt")
    addresses = Oj.load(addresses)
    locations = Oj.load(locations)

    client = Elasticsearch::Client.new
    addresses["hits"]["hits"].each do |address|
      client.index index: Rails.configuration.address_index_name, type: Rails.configuration.address_type_name,
                   id: address['_id'],
                   body: address['_source']
    end
    
    # locations["hits"]["hits"].each do |location|
    #   p location
    #   client.index index: Rails.configuration.location_index_name, type: Rails.configuration.location_type_name,
    #                id: location['_id'],
    #                body: location['_source']
    # end
  end
end




