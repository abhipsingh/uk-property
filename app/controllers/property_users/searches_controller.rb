class PropertyUsers::SearchesController < ActionController::Base

  skip_before_action :verify_authenticity_token

  def new_saved_search
    new_saved_search = params[:new_saved_search]
    property_user = PropertyUser.where(id: params[:user_id]).last
    present_searches = property_user.saved_searches
    new_searches = present_searches + [new_saved_search]
    property_user.saved_searches = new_searches
    response = property_user.save
    if response
      render json: { message: 'Search saved successfully', data: new_searches }, status: 200
    else
      render json: { message: 'Error in saving search' }, status: 400
    end
  end

  def override_saved_searches
    saved_searches = params[:saved_searches]
    property_user = PropertyUser.where(id: params[:user_id]).last
    property_user.saved_searches = saved_searches
    response = property_user.save
    if response
      render json: { message: 'Search saved successfully', data: saved_searches }, status: 200
    else
      render json: { message: 'Error in saving search' }, status: 400
    end
  end

  def saved_searches
    property_user = PropertyUser.where(id: params[:user_id]).last
    render json: { saved_searches: property_user.saved_searches }, status: 200
  end

  def shortlisted_udprns
    property_user = PropertyUser.where(id: params[:user_id]).last
    render json: { shortlisted_udprns: property_user.shortlisted_flat_ids }, status: 200
  end

  def new_shortlist
    shortlisted_flat_ids = params[:shortlisted_udprns]
    property_user = PropertyUser.where(id: params[:user_id]).last
    existing = property_user.shortlisted_flat_ids
    new_ids = (existing + shortlisted_flat_ids.map(&:to_i)).uniq
    property_user.shortlisted_flat_ids = new_ids
    response = property_user.save
    if response
      render json: { message: 'Shortlist saved successfully', data: shortlisted_flat_ids }, status: 200
    else
      render json: { message: 'Error in saving udprns' }, status: 400
    end
  end

  def delete_shortlist
    deleted_flat_ids = params[:deleted_udprns]
    property_user = PropertyUser.where(id: params[:user_id]).last
    existing = property_user.shortlisted_flat_ids
    new_ids = (existing - deleted_flat_ids.map(&:to_i)).uniq
    property_user.shortlisted_flat_ids = new_ids
    response = property_user.save
    if response
      render json: { message: 'Shortlist saved successfully', data: new_ids }, status: 200
    else
      render json: { message: 'Error in saving shortlist' }, status: 400
    end
  end

  def viewings
    property_user = PropertyUser.where(id: params[:user_id]).last
    render json: { viewings: property_user.viewings }, status: 200
  end

  def new_viewings
    viewings = params[:viewings]
    property_user = PropertyUser.where(id: params[:user_id]).last
    existing = property_user.viewings
    property_user.viewings = (existing + viewings).uniq
    response = property_user.save
    if response
      render json: { message: 'viewings saved successfully', data: viewings }, status: 200
    else
      render json: { message: 'Error in saving viewings' }, status: 400
    end
  end


  def offers
    property_user = PropertyUser.where(id: params[:user_id]).last
    render json: { offers: property_user.offers }, status: 200
  end

  def new_offers
    offers = params[:offers]
    property_user = PropertyUser.where(id: params[:user_id]).last
    existing = property_user.offers
    property_user.offers = (existing + offers).uniq
    response = property_user.save
    if response
      render json: { message: 'offers saved successfully', data: offers }, status: 200
    else
      render json: { message: 'Error in saving offers' }, status: 400
    end
  end

  def callbacks
    property_user = PropertyUser.where(id: params[:user_id]).last
    render json: { callbacks: property_user.callbacks }, status: 200
  end

  def new_callbacks
    callbacks = params[:callbacks]
    property_user = PropertyUser.where(id: params[:user_id]).last
    existing = property_user.callbacks
    property_user.callbacks = (existing + callbacks).uniq
    response = property_user.save
    if response
      render json: { message: 'callbacks saved successfully', data: callbacks }, status: 200
    else
      render json: { message: 'Error in saving callbacks' }, status: 400
    end
  end

  def messages
    property_user = PropertyUser.where(id: params[:user_id]).last
    last_20_messages = Message.where('messages.from = ? OR messages.to = ?', property_user.id, property_user.id).last(20)
    render json: { messages: last_20_messages }, status: 200
  end

  def new_message
    property_user = PropertyUser.where(id: params[:user_id]).last
    message = Message.create(content: params[:content], from: params[:user_id], to: params[:to])
    last_20_messages = Message.where('messages.from = ? OR messages.to = ?', property_user.id, property_user.id).last(20)
    if response
      render json: { message: 'messages saved successfully', data: last_20_messages }, status: 200
    else
      render json: { message: 'Error in saving messages' }, status: 400
    end
  end

  def matrix_searches
    property_user = PropertyUser.where(id: params[:user_id]).last
    render json: { messages: property_user.matrix_searches }, status: 200
  end

  def new_matrix_search
    new_matrix_search = params[:new_matrix_search]
    property_user = PropertyUser.where(id: params[:user_id]).last
    existing = property_user.matrix_searches
    property_user.matrix_searches = (existing + [new_matrix_search]).uniq
    response = property_user.save
    if response
      render json: { message: 'messages saved successfully', data: new_matrix_search }, status: 200
    else
      render json: { message: 'Error in saving messages' }, status: 400
    end
  end

end

# curl -XPOST -H 'Content-Type:application/json' 'http://localhost:3000/buyers/override/search' -d '{"user_id" : 25, "saved_searches": [{"beds":true}]   }'
# curl -XPOST -H 'Content-Type:application/json' 'http://localhost:3000/buyers/new/search' -d '{"user_id" : 25, "new_saved_search": {"beds":true}   }'
# curl -XGET -H 'Content-Type:application/json' 'http://localhost:3000/buyers/searches' -d '{"user_id" : 25}'
# curl -XGET -H 'Content-Type:application/json' 'http://localhost:3000/buyers/shortlist' -d '{"user_id" : 25}'
# curl -XPOST -H 'Content-Type:application/json' 'http://localhost:3000/buyers/new/shortlist' -d '{"user_id" : 25, "shortlisted_udprns": [123456]   }'
# curl -XPOST -H 'Content-Type:application/json' 'http://localhost:3000/buyers/delete/shortlist' -d '{"user_id" : 25, "deleted_udprns": [123456]   }'
# curl -XGET -H 'Content-Type:application/json' 'http://localhost:3000/buyers/viewings' -d '{"user_id" : 25}'
# curl -XPOST -H 'Content-Type:application/json' 'http://localhost:3000/buyers/new/viewings' -d '{"user_id" : 25, "viewings": [123456]   }'
# curl -XGET -H 'Content-Type:application/json' 'http://localhost:3000/buyers/offers' -d '{"user_id" : 25}'
# curl -XPOST -H 'Content-Type:application/json' 'http://localhost:3000/buyers/new/offers' -d '{"user_id" : 25, "offers": [123456]   }'
# curl -XGET -H 'Content-Type:application/json' 'http://localhost:3000/buyers/callbacks' -d '{"user_id" : 25}'
# curl -XPOST -H 'Content-Type:application/json' 'http://localhost:3000/buyers/new/callbacks' -d '{"user_id" : 25, "callbacks": [123456]   }'
# curl -XGET -H 'Content-Type:application/json' 'http://localhost:3000/buyers/messages' -d '{"user_id" : 25}'
# curl -XPOST -H 'Content-Type:application/json' 'http://localhost:3000/buyers/new/message' -d '{"user_id" : 25, "to": 123456, "content" : "Ta da da da"   }'
# curl -XPOST -H 'Content-Type:application/json' 'http://localhost:3000/buyers/new/matrix/search' -d '{"user_id" : 25, "new_matrix_search": "Merseyside"   }'
# curl -XGET -H 'Content-Type:application/json' 'http://localhost:3000/buyers/matrix/searches' -d '{"user_id" : 25}'


