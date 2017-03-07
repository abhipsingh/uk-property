module EventsHelper
  MESSAGE_HASH = Hash.new { nil }
  MESSAGE_HASH['viewing_stage'] = { scheduled_viewing_time: Time.now.to_s }.to_json
  MESSAGE_HASH['offer_made_stage'] = { offer_price: nil, offer_date: Date.today.to_s }
  MESSAGE_HASH['conveyance_stage'] = { scheduled_conveyance_time: 1.day.from_now.to_s }.to_json
  MESSAGE_HASH['contract_exchange_stage'] = { contract_date: 1.day.from_now.to_s }.to_json
  MESSAGE_HASH['completion_stage'] = { expected_completion_date: (1..3).to_a.sample.days.from_now.to_date.to_s }.to_json


  def message_value(doc, stage)
    message = MESSAGE_HASH[stage.to_s]
    if stage.to_s == 'offer_made_stage'
      message = {}
      random_val = (0..10).to_a.sample
      price = doc['asking_price'] || doc['offers_over'] || doc['fixed_price']
      message[:offer_price] = (price.to_f*(1.0+(random_val.to_f/100.0))).to_i
      message = message.to_json
    elsif stage.to_s == 'sold'
      message = {}
      random_val = (0..10).to_a.sample
      price = doc['asking_price'] || doc['offers_over'] || doc['fixed_price']
      message[:final_price] = (price.to_f*(1.0+(random_val.to_f/100.0))).to_i
      message[:exchange_of_contracts] = (3..5).to_a.sample.days.from_now.to_date.to_s
      message = message.to_json
    end
    message
  end

  def process_event_helper(event, doc)
    message = message_value(doc, event)
    udprn = doc['udprn']
    req = { udprn: udprn, event: event, message: message, type_of_match: 'perfect', buyer_id: PropertyBuyer.first.id }
    prev_count = Event.count
    post :process_event, req.to_json, req.merge(format: 'json')
    current_count = Event.count
    assert_response 200
    assert_equal prev_count + 1, current_count
  end

end