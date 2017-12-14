module Api
  module V0
    class AgentSearchController < ApplicationController
      def search
        klass = params[:type] == 'agent' ? Agent : Agents::Branch
        results = klass
        results = results.where('lower(name) LIKE ?', "#{params[:name].downcase}%") if params[:name]
        results = results.where(agent_id: params[:branch_id].to_i) if params[:branch_id]
        results = results.limit(10)
        render json: results
      end
    end
  end
end

