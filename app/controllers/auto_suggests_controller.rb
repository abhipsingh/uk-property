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


  def predictive_search
    regexes = [[/^([A-Z]{1,2})([0-9]{0,3})$/, /^([A-Z]{1,2})([0-9]{1,3})([A-Z]{0,2})$/], /^([0-9]{1,2})([A-Z]{0,3})$/]
    str = nil
    if check_if_postcode?(params[:str].upcase, regexes)
      str = params[:str].upcase.strip
    else
      str = params[:str].gsub(',',' ').strip.downcase
      str = str.gsub('.','')
      str = str.gsub('-','')
    end
    results, code = PropertyService.get_results_from_es_suggest(str, 30)
    Rails.logger.info("Prediction str #{str} #{results}")
    #Rails.logger.info(results)
    predictions = Oj.load(results)['postcode_suggest'][0]['options']
    #predictions.each { |t| t['score'] = t['score']*100 if t['payload']['hash'] == params[:str].upcase.strip }
    #predictions.each { |t| t['building_number'] = t['payload']['hash'].split('_')[*100 if t['payload']['hash'] == params[:str].upcase.strip }
    predictions.sort_by!{|t| (1.to_f/t['score'].to_f) }
    final_predictions = []
    #Rails.logger.info(predictions)
    udprns = []
    predictions = predictions.each do |t|
      text = t['text']
      if text.end_with?('bt') || text.end_with?('dl') || text.end_with?('td') || text.end_with?('dtd')
        udprns.push(text.split('_')[0].to_i)
      elsif text.start_with?('district') || text.start_with?('sector') || text.start_with?('unit')
        udprns.push(text.split('|')[1].to_i)
      end
    end
    #Rails.logger.info(udprns)
    details = PropertyService.bulk_details(udprns)
    details = details.map{|t| t.with_indifferent_access }

    counter = 0
    predictions = predictions.each_with_index do |t, index|
      text = t['text']
      if text.end_with?('bt')
        address = details[counter][:address]
        udprn = text.split('_')[0]
        hash = "@_@_@_@_@_@_@_@_#{udprn}"
        final_predictions.push({ hash: hash, output: address, type: 'building_type' })
        counter += 1
      elsif text.end_with?('dl') 
        output = "#{details[counter]['dependent_locality']} (#{details[counter]['post_town']}, #{details[counter]['county']}, #{details[counter]['district']})"
        hash = MatrixViewService.form_hash(details[counter], :dependent_locality)
        final_predictions.push({ hash: hash, output: output , type: 'dependent_locality'})
        counter += 1
      elsif  text.end_with?('dtd')
        loc = ''
        hash_loc = '@'
        Rails.logger.info("UDPRN #{details[counter]['udprn']}")
        details[counter]['dependent_locality'].nil? ? loc = '' : loc = "#{details[counter]['dependent_locality']}, "
        output = "#{details[counter]['dependent_thoroughfare_description']} (#{loc}#{details[counter]['post_town']}, #{details[counter]['county']}, #{details[counter]['district']})"
        hash = MatrixViewService.form_hash(details[counter], :dependent_thoroughfare_description)
        final_predictions.push({ hash: hash, output: output, type: 'dependent_thoroughfare_description' })
        counter += 1
      elsif text.end_with?('td')
        loc = ''
        details[counter]['dependent_locality'].nil? ? loc = '' : loc = "#{details[counter]['dependent_locality']}, "
        output = "#{details[counter]['thoroughfare_description']} (#{loc}#{details[counter]['post_town']}, #{details[counter]['county']}, #{details[counter]['district']})"
        hash = MatrixViewService.form_hash(details[counter], :thoroughfare_description)
        final_predictions.push({ hash: hash, output: output, type: 'thoroughfare_description' })
        counter += 1
      elsif text.start_with?('district') 
        output = "#{details[counter]['district']} (#{details[counter]['post_town']})"
        hash = MatrixViewService.form_hash(details[counter], :district)
        final_predictions.push({ hash: hash, output: output, type: 'district' })
        counter += 1
      elsif text.start_with?('sector') 
        output = calculate_formatted_string(details[counter], :sector)
        hash = MatrixViewService.form_hash(details[counter], :sector)
        final_predictions.push({ hash: hash, output: output, type: 'sector' })
        counter += 1
      elsif text.start_with?('unit')
        output = calculate_formatted_string(details[counter], :unit)
        hash = MatrixViewService.form_hash(details[counter], :unit)
        final_predictions.push({ hash: hash, output: output, type: 'unit' })
        counter += 1
      elsif text.start_with?('post_town') || text.start_with?('county')
        output_parts = text.split('|')[1].split('_')
        hash = nil
        county = output_parts[1]
        post_town = output_parts[0]
        location_hash = { post_town: post_town, county: county }
        output = nil
        if text.start_with?('post_town')
          hash = MatrixViewService.form_hash(location_hash, :post_town)
          if post_town == 'London'
            output = county + ' (' + post_town + ')'
          else
            output = post_town + ' (' + county + ')'
          end
        else
          location_hash[:county] = post_town
          hash = MatrixViewService.form_hash(location_hash, :county)
          output = post_town
        end
        final_predictions.push({ hash: hash, output: output, type: text.split('|')[0] })
      end
    end
    #Rails.logger.info(details)
    #final_predictions = final_predictions.uniq{|t| t[:hash] }
    render json: final_predictions, status: code
  end

end
