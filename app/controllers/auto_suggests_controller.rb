class AutoSuggestsController < ActionController::Base
  
  ### Predictions about new build
  ### curl -XGET 'http://52.66.124.42/properties/new/suggest?str=flat%203%20160'
  def suggest_new_properties
    str = params[:str].gsub(',',' ').downcase
    results, code = PropertyService.get_results_from_es_suggest_new_build(str, 100)
    predictions = Oj.load(results)['postcode_suggest'][0]['options']
    udprns = []

    predictions = predictions.each do |t|
      text = t['text']
      udprns.push(text.split('_')[0].to_i) if text.end_with?('bt') || text.end_with?('td') || text.end_with?('dtd')
    end

    details = PropertyService.bulk_details(udprns)
    details = details.map{ |t| t.with_indifferent_access }
    counter = 0
    final_predictions = []
    predictions.each_with_index do |t, index|
      text = t['text']
      if text.end_with?('bt') || text.end_with?('td') || text.end_with?('dtd')
        address = PropertyDetails.address(details[counter])
        udprn = text.split('_')[0]
        hash = "@_@_@_@_@_@_@_@_#{udprn}"
        final_predictions.push({ hash: hash, output: address, type: 'building_type' })
      end 
      counter += 1
    end

    render json: final_predictions, status: 200
  end

end
