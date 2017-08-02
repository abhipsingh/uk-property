### Base controller
class BuyersController < ActionController::Base

	#### When basic details of the buyer is saved
  #### curl -XPOST -H "Content-Type: application/json"  'http://localhost/buyers/7/edit' -d '{ "status" : "Green", "buying_status" : "First time buyer", "budget_from" : 5000, "budget_to": 100000, "chain_free" : false, "funding_status" : "Mortgage approved", "biggest_problem" : "Money" }'
  #### Another example of editing name, mobile and image_url
  #### curl -XPOST -H "Content-Type: application/json"  'http://localhost/buyers/43/edit' -d '{ "name" : "Jack Bing", "image_url" : "random_image_url", "mobile" : "9876543321" }'
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
		buyer.mobile = params[:mobile] if params[:mobile]
		buyer.image_url = params[:image_url] if params[:image_url]
		buyer.name = params[:name] if params[:name]
		buyer.first_name = params[:first_name] if params[:first_name]
		buyer.last_name = params[:last_name] if params[:last_name]
		buyer.property_types = params[:property_types] if params[:property_types]
		buyer.locations = params[:locations] if params[:locations]
		buyer.min_beds = params[:min_beds] if params[:min_beds]
		buyer.max_beds = params[:max_beds] if params[:max_beds]
		buyer.min_baths = params[:min_baths] if params[:min_baths]
		buyer.max_baths = params[:max_baths] if params[:max_baths]
		buyer.min_receptions = params[:min_receptions] if params[:min_receptions]
		buyer.max_receptions = params[:max_receptions] if params[:max_receptions]
		buyer.password = params[:password] if params[:password]
		buyer.save!
		render json: { message: 'Saved buyer successfully', details: buyer.as_json }, status: 201
	end

end
