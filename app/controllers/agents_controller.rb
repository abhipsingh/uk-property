class AgentsController < ApplicationController
  def search
    klass = params[:type] == 'Agent' ? Agent : Agents::Branch
    results = klass.where('lower(name) LIKE ?', "#{params[:name].downcase}")
    render json: results
  end
end