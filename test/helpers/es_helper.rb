module EsHelper
  CLIENT = Elasticsearch::Client.new
  
  def index_es_address(id, body)
    CLIENT.index index: Rails.configuration.address_index_name,
                 type: Rails.configuration.address_type_name,
                 id: id,
                 body: body
  end

  def delete_es_address(id)
    CLIENT.delete index: Rails.configuration.address_index_name,
                  type: Rails.configuration.address_type_name,
                  id: id
  end

  def get_es_address(id)
    CLIENT.get index: Rails.configuration.address_index_name,
               type: Rails.configuration.address_type_name,
               id: id
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
