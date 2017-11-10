module EsHelper
  CLIENT = Elasticsearch::Client.new
  
  def create_address_mapping_load_testing
    mapping = Oj.load(File.read("#{Rails.root}/addresses_mapping.json"))
    mapping['mappings'][Rails.configuration.address_type_name_load_testing] = mapping['mappings'].delete('address')
    mapping['mappings'][Rails.configuration.address_type_name_load_testing].delete('_source')
    mapping['mappings'][Rails.configuration.address_type_name_load_testing].delete('_all')
    CLIENT.indices.create index: Rails.configuration.address_index_name_load_testing,
                          body: mapping
  end
  
  def index_es_address(id, body)
    PropertyDetails.update_details(CLIENT, id, body)
  end

  def bulk_update_adresses(body)
    CLIENT.bulk body: body
  end

  def delete_es_address(id)
    ardb_client = Rails.configuration.arbd_client
    ardb_client.del(id)
    CLIENT.delete index: Rails.configuration.address_index_name,
                  type: Rails.configuration.address_type_name,
                  id: id
  end

  def get_es_address(id)
    PropertyDetails.details(id)
  end

  def update_es_address(id, doc)
    PropertyDetails.update_details(CLIENT, id, doc)
    sleep(2)
  end

  def create_location_doc(id, body)
    CLIENT.index index: Rails.configuration.location_index_name,
                 type: Rails.configuration.location_type_name,
                 id: id,
                 body: body
  end

  def destroy_location_doc(id)
     CLIENT.delete index: Rails.configuration.location_index_name,
                   type: Rails.configuration.location_type_name,
                   id: id
  end

  def get_es_location(id)
    CLIENT.get index: Rails.configuration.location_index_name,
               type: Rails.configuration.location_type_name,
               id: id
  end

  def update_es_location(id, doc)
    CLIENT.update index: Rails.configuration.location_index_name, 
                  type: Rails.configuration.location_type_name, 
                  id: id, 
                  body: { doc: doc }
  end

  def delete_all_docs(index=Rails.configuration.address_index_name, type=Rails.configuration.address_type_name)
    query = { fields: [], query: { match_all: {}} }
    body, status = PropertyService.post_url(index, type, '_search', query)
    docs = Oj.load(body)
    ids = docs['hits']['hits'].map{ |e| e['_id'] }
    ids.each do |id|
      if index == Rails.configuration.address_index_name
        delete_es_address(id)
      else
        destroy_location_doc(id)
      end
    end
    ardb_client = Rails.configuration.ardb_client
    ardb_client.flushdb
  end

  def attach_agent_to_property_and_update_details(agent_id, udprn, property_status_type, verification_status, beds, baths, receptions)
    agent_id = Agents::Branches::AssignedAgent.last.id
    doc = {
        agent_id: agent_id,
        property_status_type: property_status_type,
        verification_status: verification_status,
        beds: beds,
        baths: baths,
        receptions: receptions,
        udprn: udprn
    }
    update_es_address(udprn, doc)
    sleep(1)
  end

end
