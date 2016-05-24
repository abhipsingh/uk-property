module Api
  module V0
    class AgentsController < ApplicationController
      def search
        klass = params[:type] == 'Agent' ? Agent : Agents::Branch
        results = klass.where('lower(name) LIKE ?', "#{params[:name].downcase}").limit(100)
        render json: results
      end
    end
  end
end
