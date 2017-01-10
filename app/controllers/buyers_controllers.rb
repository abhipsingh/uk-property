### Base controller
class BuyersController < ActionController::Base

	#### When basic details of the buyer is saved
  #### curl -XPOST -H "Content-Type: application/json"  'http://localhost/buyers/7/edit' -d '{ "status" : "Green", "buying_status" : "First time buyer", "budget_from" : 5000, "budget_to": 100000, "chain_free" : false, "funding_status" : "Mortgage approved", "biggest_problem" : "Money" }'
	def edit_basic_details
		buyer = PropertyBuyer.find(params[:id])
		buying_status = PropertyBuyer::BUYING_STATUS_HASH[params[:buying_status]] if params[:buying_status]
		budget_from = params[:budget_from].to_i if params[:budget_from]
		budget_to = params[:budget_to].to_i if params[:budget_to]
		status = PropertyBuyer::STATUS_HASH[params[:status].downcase.to_sym] if params[:status]
		funding_status = PropertyBuyer::FUNDING_STATUS_HASH[params[:funding_status]] if params[:funding_status]
		biggest_problem = PropertyBuyer::BIGGEST_PROBLEM_HASH[params[:biggest_problem]] if params[:biggest_problem]
		chain_free = params[:chain_free] if !params[:chain_free].nil?
		Rails.logger.info("CHAIN_FREE_#{chain_free}")
		buyer.buying_status = buying_status if buying_status
		buyer.budget_from = budget_from if budget_from
		buyer.budget_to = budget_to if budget_to
		buyer.status = status if status
		buyer.funding = funding_status if funding_status
		buyer.biggest_problem = biggest_problem if biggest_problem
		buyer.chain_free = chain_free unless chain_free.nil?
		buyer.save!
		render json: { message: 'Saved buyer successfully' }, status: 201
	end
end