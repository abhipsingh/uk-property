# module Rents
#   class AgentsController < ApplicationController
    
#     #### For agents the quotes page has to be shown in which all his recent or the new properties in the area
#     #### Will be published
#     #### curl -XGET -H "Content-Type: application/json" 'http://localhost/rents/agents/properties/recent/quotes?agent_id=1234'
#     #### For applying filters i) payment_terms
#     #### curl -XGET -H "Content-Type: application/json" 'http://localhost/rents/agents/properties/recent/quotes?agent_id=1234&payment_terms=Pay%20upfront'
#     #### ii) services_required
#     #### curl -XGET -H "Content-Type: application/json" 'http://localhost/rents/agents/properties/recent/quotes?agent_id=1234&services_required=Ala%20Carte'
#     #### ii) quote_status
#     #### curl -XGET -H "Content-Type: application/json" 'http://localhost/rents/agents/properties/recent/quotes?agent_id=1234&quote_status=Won'
    
#     def recent_properties_for_quotes_rent
#       cache_parameters = [ :agent_id, :payment_terms, :services_required, :quote_status, :search_str ]
#       cache_response(params[:agent_id].to_i, cache_parameters) do
#         results = []
#         response = {}
#         status = 200
#         begin
#           results = Agents::Branches::AssignedAgent.find(params[:agent_id].to_i).recent_properties_for_quotes(params[:payment_terms], params[:services_required], params[:quote_status], params[:search_str], 'Rent') if params[:agent_id]
#           response = results.empty? ? {"quotes" => results, "message" => "No quotes to show"} : {"quotes" => results}
#         rescue => e
#           Rails.logger.error "Error with agent quotes => #{e}"
#           response = {"quotes" => results, "message" => "Error in showing quotes", "details" => e.message}
#           status = 500
#         end
        
#         render json: response, status: status
#       end
#     end


#     #### For agents the leads page has to be shown in which the recent properties have been claimed
#     #### Those properties have just been claimed recently in the area
#     #### curl -XGET -H "Content-Type: application/json" 'http://localhost/rents/agents/properties/recent/claims?agent_id=1234'
#     def recent_properties_for_claim_rent
#       cache_parameters = []
#       cache_response(params[:agent_id].to_i, cache_parameters) do
#         response = {}
#         status = 200
#         begin
#           results = []
#           status = params[:status]
#           if params[:agent_id].nil?
#             response = {"message" => "Agent ID missing"}
#           else
#             results = Agents::Branches::AssignedAgent.find(params[:agent_id].to_i).recent_properties_for_claim(status, 'Rent')
#             response = results.empty? ? {"leads" => results, "message" => "No leads to show"} : {"leads" => results}
#           end
#         rescue ActiveRecord::RecordNotFound
#           response = {"message" => "Agent not found in database"}
#         rescue => e
#           response = {"leads" => results, "message" => "Error in showing leads", "details" => e.message}
#           status = 500
#         end
#         Rails.logger.info "sending response for recent claims property #{response.inspect}"
#         render json: response, status: status
#       end
#     end


#     #### On demand quicklink for all the properties of agents, or group or branch or company
#     #### To get list of properties for the concerned agent
#     #### curl -XGET -H "Content-Type: application/json" 'http://localhost/rents/agents/properties?agent_id=1234'
#     #### Filters on property_status_type, ads
#     def detailed_properties_rent
#       cache_parameters = [ :agent_id, :property_status_type, :verification_status, :ads ].map{ |t| params[t].to_s }
#       cache_response(params[:agent_id].to_i, cache_parameters) do
#         response = {}
#         results = []

#         unless params[:agent_id].nil?
#           #### TODO: Need to fix agents quotes when verified by the vendor
#           search_params = { limit: 10000, fields: 'udprn' }
#           search_params[:agent_id] = params[:agent_id].to_i
#           search_params[:property_status_type] = 'Rent'
#           # search_params[:verification_status] = true
#           search_params[:ads] = params[:ads] if params[:ads] == true
#           property_ids = lead_property_ids = quote_property_ids = active_property_ids = []
#           quote_model = Agents::Branches::AssignedAgents::Quote
#           lead_model = Agents::Branches::AssignedAgents::Lead
#           property_status_type = Trackers::Buyer::PROPERTY_STATUS_TYPES['Rent']
#           if !(params[:ads].to_s == 'true' || params[:ads].to_s == 'false')
#             quote_property_ids = quote_model.where(agent_id: params[:agent_id])
#                                             .where(property_status_type: property_status_type)
#                                             .pluck(:property_id)
#             lead_property_ids = lead_model.where(agent_id: params[:agent_id].to_i)
#                                           .where(property_status_type: property_status_type)
#                                           .pluck(:property_id)
#             property_ids = lead_property_ids + quote_property_ids
#           else
#             search_params[:ads] = params[:ads]
#           end
    
#           api = PropertySearchApi.new(filtered_params: search_params)
#           api.apply_filters
#           body, status = api.fetch_data_from_es
#           active_property_ids = body.map { |e| e['udprn'] }
    
#           ### Get all properties for whom the agent has won leads
#           property_ids = (active_property_ids + property_ids).uniq
#           # Rails.logger.info("property ids found for detailed properties (agent) = #{property_ids}")
#           results = property_ids.uniq.map { |e| Trackers::Buyer.new.push_events_details(PropertyDetails.details(e), 'Rent') }
#           response = results.empty? ? {"properties" => results, "message" => "No properties to show"} : {"properties" => results}
#           # Rails.logger.info "Sending results for detailed properties (agent) => #{results.inspect}"
#         else
#           response = {"message": "Agent ID mandatory for getting properties"}
#         end
#         Rails.logger.info "Sending response for detailed properties (agent) => #{response.inspect}"
#         render json: response, status: 200
#       end
#     end


#     #### For agents implement filter of agents group wise, company wise, branch, location wise,
#     #### and agent_id wise. 
#     #### New Changes and additions
#     #### The leads can be filtered as well. Four different kind of filters apply. 
#     #### i) Type of buyer enquiry
#     #### ii) Type of match
#     #### iii) Qualifying stage
#     #### iv) Rating
#     #### v) By Buyer's funding type, chain free, biggest problems etc
#     #### curl -XGET -H "Content-Type: application/json" 'http://localhost/rents/agents/enquiries/new/1234'
#     def agent_new_enquiries_rent
#       results = []
#       final_response = {}
#       status = 200
#       cache_parameters = [ :enquiry_type, :type_of_match, :qualifying_stage, :rating, :buyer_status, :buyer_funding, :buyer_biggest_problem, :buyer_chain_free, :search_str, :budget_from, :budget_to ].map{ |t| params[t].to_s }
#       cache_response(params[:agent_id].to_i, cache_parameters) do
#         results = Trackers::Buyer.new.property_enquiry_details_buyer(params[:agent_id].to_i, params[:enquiry_type], params[:type_of_match], 
#           params[:qualifying_stage], params[:rating], params[:buyer_status], params[:buyer_funding], params[:buyer_biggest_problem], params[:buyer_chain_free], 
#           params[:search_str], params[:budget_from], params[:budget_to], 'Rent') if params[:agent_id]
#         final_response = results.empty? ? {"enquiries" => results, "message" => "No quotes to show"} : {"enquiries" => results}
#         render json: final_response, status: status
#       end
#     end

#     ### Verify the agent as the intended agent and udprn as the correct udprn
#     ### curl  -XPOST -H  "Content-Type: application/json" 'http://localhost/vendors/udprns/10968961/agents/23/rent/verify'
#     def verify_agent
#       client = Elasticsearch::Client.new host: Rails.configuration.remote_es_host
#       udprn = params[:udprn].to_i
#       agent_id = params[:agent_id].to_i
#       response, status = PropertyDetails.update_details(client, udprn, { property_status_type: 'Rent', verification_status: true, agent_id: agent_id, agent_status: 2 })
#       response['message'] = "Agent verification successful." unless status.nil? || status!=200
#       render json: response, status: status
#     rescue Exception => e
#       Rails.logger.info("VERIFICATION_FAILURE_#{e}")
#       render json: { message: 'Verification failed due to some error' }, status: 400
#     end

#     ### Verify the property as the intended agent and udprn as the correct udprn.
#     ### Done when the invited vendor(through email) verifies the property as his/her
#     ### property and the agent as his/her agent.
#     ### curl  -XPOST -H  "Content-Type: application/json" 'http://localhost/vendors/udprns/10968961/verify' -d '{ verified: true }'
#     def verify_property_from_vendor
#       client = Elasticsearch::Client.new host: Rails.configuration.remote_es_host
#       response, status = nil
#       udprn = params[:udprn].to_i
#       if params[:verified].to_s == 'true'
#         response, status = PropertyDetails.update_details(client, udprn, { property_status_type: 'Rent', verification_status: true })
#         response['message'] = "Property verification successful." unless status.nil? || status!=200
#       else
#         response['message'] = "Property verification unsuccessful. This incident will be reported" unless status.nil? || status!=200
#         ### TODO: Take further action when the vendor rejects verification
#       end
#       render json: response, status: status
#     rescue Exception => e
#       Rails.logger.info("VENDOR_PROPERTY_VERIFICATION_FAILURE_#{e}")
#       render json: { message: 'Verification failed due to some error' }, status: 400
#     end


#     # ### Verify the property's basic attributes and attach the crawled property to a udprn
#     # ### Done when the agent attaches the udprn to the property
#     # ### curl  -XPOST -H  "Content-Type: application/json" 'http://localhost/agents/properties/10968961/verify' -d '{ "property_type" : "Barn conversion", "beds" : 1, "baths" : 1, "receptions" : 1, "property_id" : 340620, "agent_id": 1234, "vendor_email": "residentevil293@prophety.co.uk", "assigned_agent_email" :  "residentevil293@prophety.co.uk" }'
#     # def verify_property_from_agent
#     #   udprn = params[:udprn].to_i
#     #   agent_id = params[:agent_id].to_i
#     #   agent_service = AgentService.new(agent_id, udprn)
#     #   property_attrs = {
#     #     property_status_type: 'Rent',
#     #     verification_status: false,
#     #     property_type: params[:property_type],
#     #     receptions: params[:receptions].to_i,
#     #     beds: params[:beds].to_i,
#     #     baths: params[:baths].to_i,
#     #     receptions: params[:receptions].to_i,
#     #     property_id: params[:property_id].to_i,
#     #     details_completed: true
#     #   }
#     #   vendor_email = params[:vendor_email]
#     #   assigned_agent_email = params[:assigned_agent_email]
#     #   agent_count = Agents::Branches::AssignedAgent.where(id: agent_id).count > 0
#     #   raise StandardError, "Branch and agent not found" if agent_count == 0
#     #   response, status = agent_service.verify_crawled_property_from_agent(property_attrs, vendor_email, assigned_agent_email)
#     #   response['message'] = "Property details updated." unless status.nil? || status!=200
#     #   render json: response, status: status
#     # rescue Exception => e
#     #   Rails.logger.info("AGENT_PROPERTY_VERIFICATION_FAILURE_#{e}")
#     #   render json: { message: 'Verification failed due to some error' }, status: 400
#     # end

#     ### Add manual property's basic attributes and attach the crawled property to a udprn
#     ### Done when the agent attaches the udprn to the property
#     ### curl  -XPOST -H  "Content-Type: application/json" 'http://localhost/agents/properties/10968961/manual/verify' -d '{ "property_type" : "Barn conversion", "beds" : 1, "baths" : 1, "receptions" : 1, "agent_id": 1234, "vendor_email": "residentevil293@prophety.co.uk", "assigned_agent_email" :  "residentevil293@prophety.co.uk" }'
#     def verify_manual_property_from_agent
#       udprn = params[:udprn].to_i
#       agent_id = params[:agent_id].to_i
#       agent_service = AgentService.new(agent_id, udprn)
#       property_attrs = {
#         property_status_type: 'Rent',
#         verification_status: false,
#         property_type: params[:property_type],
#         receptions: params[:receptions].to_i,
#         beds: params[:beds].to_i,
#         baths: params[:baths].to_i,
#         receptions: params[:receptions].to_i,
#         property_id: params[:property_id].to_i,
#         details_completed: false
#       }
#       vendor_email = params[:vendor_email]
#       assigned_agent_email = params[:assigned_agent_email]
#       agent_count = Agents::Branches::AssignedAgent.where(id: agent_id).count > 0
#       raise StandardError, "Branch and agent not found" if agent_count == 0
#       response, status = agent_service.verify_manual_property_from_agent(property_attrs, vendor_email, assigned_agent_email)
#       response['message'] = "Property details updated." unless status.nil? || status!=200
#       render json: response, status: status
#     rescue Exception => e
#       Rails.logger.info("AGENT_MANUAL_PROPERTY_VERIFICATION_FAILURE_#{e}")
#       render json: { message: 'Verification failed due to some error' }, status: 400
#     end

#   end
# end
