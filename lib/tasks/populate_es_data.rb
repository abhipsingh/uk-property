require 'oj'
require 'net/http'

class PopulateEsData
  def self.etup
    addresses = File.read("addresses.json")
    locations = File.read("locations.json")
    Oj.load(addresses)
    Oj.load(locations)

    addresses["hits"]["hits"].each do |address|
      p address
    end
    
    locations["hits"]["hits"].each do |location|
      p location
    end
  end
end




