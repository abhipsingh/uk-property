class LeadsController < ApplicationController
  around_action :authenticate_agent, only: [ :submit_lead_visit_time ]#, :agents_recent_properties_for_claim ]

  ### Edit lead visit time
  ### curl -XPOST  -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo4OCwiZXhwIjoxNTAzNTEwNzUyfQ.7zo4a8g4MTSTURpU5kfzGbMLVyYN_9dDTKIBvKLSvPo" 'http://localhost/agents/lead/submit/visit/time' -d '{ "udprn" : "any udprn", "visit_time" : "2017-12-03T11:22:00Z" }'
  def submit_lead_visit_time
    agent = @current_user
    lead = Agents::Branches::AssignedAgents::Lead.where(agent_id: agent.id, property_id: params[:udprn].to_i).where.not(vendor_id: nil).last
    if lead
      lead.visit_time = Time.parse(params[:visit_time])
      lead.save!
      render json: { message: 'Visit time successully submitted' }, status: 200
    else
      render json: { message: 'No lead found for this property' }, status: 401
    end
  end

  #### For agents the leads page has to be shown in which the recent properties have been claimed
  #### Those properties have just been claimed recently in the area
  #### curl -XGET -H "Content-Type: application/json" 'http://localhost/agents/properties/recent/claims?agent_id=1234'
  #### For rent properties
  #### curl -XGET -H "Content-Type: application/json" 'http://localhost/agents/properties/recent/claims?agent_id=1234&property_for=Rent'
  def agents_recent_properties_for_claim
    cache_parameters = []
    #cache_response(params[:agent_id].to_i, cache_parameters) do
      response = {}
      status = 200
      #begin
        results = []
        agent_status = params[:status]
        if params[:agent_id].nil?
          response = { message: 'Agent ID missing' }
        else
          agent = Agents::Branches::AssignedAgent.find(params[:agent_id].to_i)
          if !agent.locked
            owned_property = params[:manually_added] == 'true' ? true : nil
            owned_property = params[:manually_added] == 'false' ? false : owned_property
            count = params[:count].to_s == 'true'
            results, count = agent.recent_properties_for_claim(agent_status, 'Sale', params[:buyer_id], params[:hash_str], agent.is_premium, params[:page], owned_property, count, params[:latest_time])
            response = (!results.is_a?(Fixnum) && results.empty?) ? {"leads" => results, "message" => "No leads to show", 'count' => count } : {"leads" => results, 'count' => count }
          else
            lead = Agents::Branches::AssignedAgents::Lead.where(agent_id: agent.id)
                                                         .where(expired: true)
                                                         .order('updated_at DESC')
                                                         .last
            address = PropertyDetails.details(lead.property_id)[:_source][:address]
            deadline = lead.created_at + Agents::Branches::AssignedAgents::Lead::VERIFICATION_DAY_LIMIT
            response = { leads: [], address: address, locked: true, count: 0 }
            status = 400
          end
        end
#      rescue ActiveRecord::RecordNotFound
#        response = { message: 'Agent not found in database' }
#        status = 404
#      rescue => e
#        response = { leads: results, message: 'Error in showing leads', details: e.message}
#        status = 500
#      end
      #Rails.logger.info "sending response for recent claims property #{response.inspect}"
      render json: response, status: status
    #end
  end

  private
  def user_valid_for_viewing?(klass)
    @current_user = AuthorizeApiRequest.call(request.headers, klass).result
  end

  def authenticate_agent
    if user_valid_for_viewing?('Agent')
      yield
    else
      render json: { message: 'Authorization failed' }, status: 401
    end
  end

  def authenticate_vendor
    if user_valid_for_viewing?('Vendor')
      yield
    else
      render json: { message: 'Authorization failed' }, status: 401
    end
  end

end

