class LeadsController < ApplicationController

  ### Edit lead visit time
  ### curl -XPOST  -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo4OCwiZXhwIjoxNTAzNTEwNzUyfQ.7zo4a8g4MTSTURpU5kfzGbMLVyYN_9dDTKIBvKLSvPo" 'http://localhost/agents/lead/submit/visit/time' -d '{ "udprn" : "any udprn", "visit_time" : "2017-12-03T11:22:00Z" }'
  def submit_lead_visit_time
    agent = user_valid_for_viewing?('Agent')
    if !agent.nil?
      lead = Agents::Branches::AssignedAgents::Lead.where(agent_id: agent.id, property_id: params[:udprn].to_i).where.not(vendor_id: nil).last
      if lead
        lead.visit_time = Time.parse(params[:visit_time])
        lead.save!
        render json: { message: 'Visit time successully submitted' }, status: 200
      else
        render json: { message: 'No lead found for this property' }, status: 401
      end
    else
      render json: { message: 'Authorization failed' }, status: 401
    end
  end

  private
  def user_valid_for_viewing?(klass)
    AuthorizeApiRequest.call(request.headers, klass).result
  end

end

