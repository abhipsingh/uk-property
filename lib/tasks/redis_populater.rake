namespace :redis_populater do
  desc "Populate new udprns from new property builds"
  task new_properties: :environment do
    file_name = '/mnt3/corrected_not_yet_built.csv'
    counter = 0
    details_arr = []

    File.open(file_name, 'r').each_line do |line|
      line_detail = line.strip
      arr_of_strs = line_detail.split(',')
      result = {}
      PropertyService::LOCALITY_ATTRS.each_with_index do |attr, index|
        result[attr] = arr_of_strs[index]
      end
      result[:double_dependent_locality] = nil
      dtd = result[:throroughfare_description]
      result[:throroughfare_description] = result[:dependent_throroughfare_description]
      result[:dependent_throroughfare_description] = dtd
      result[:not_yet_built] = true
      post_town = result[:post_town]
      result[:county] = MatrixViewCount::COUNTY_MAP[post_town.upcase] if result[:post_town]
      details_arr.push(result)

      if details_arr.length == 400
        resp = PropertyService.bulk_set(details_arr)
        details_arr = []
      end
      p "#{counter/10000}" if counter % 10000 == 0

      counter += 1
    end

    PropertyService.bulk_set(details_arr)

  end

end

