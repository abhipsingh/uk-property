module Api
  module V0
    class AgentsController < ApplicationController
      def search
        klass = params[:type] == 'Agent' ? Agent : Agents::Branch
        results = klass.where('lower(name) LIKE ?', "#{params[:name].downcase}").limit(100)
        render json: results
      end
    end


    def quotes_per_property
      quotes = AgentApi.new(params[:property_id].to_i, params[:agent_id].to_i).calculate_quotes
      render json: quotes, status: 200
    end
  end
end
