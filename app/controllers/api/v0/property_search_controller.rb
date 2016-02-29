module Api
  module V0
    class PropertySearchController < ActionController::Base
      def search
        response = Hash.new
        api = ::PropertyDetailsRepo.new(filtered_params: params)
        result, status = api.filter
        render :json => result, :status => status
      end
    end
  end
end