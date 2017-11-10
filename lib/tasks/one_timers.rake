namespace :one_timers do

  desc "matrix testing"
  task matrix_testing: :environment do
    require_relative '../../test/helpers/es_helper'
    include EsHelper
    beds_sample = [0, 1, 2, 3, 4]
    baths_sample = [0, 1, 2, 3, 4]
    receptions_sample = [0, 1, 2, 3, 4]
    random = Random.new
    property_type_sample = ['Barn Conversion', 'Bungalow', 'Land', 'Countryside', 'Cottage', 'Farm', 'Flat', 'Lodge', 'Maisonette', 'Terraced House']
    #create_address_mapping_load_testing
    sleep(2)
    batch_size = 10000
    Uk::Property.find_in_batches(batch_size: batch_size) do |properties|
      udprns = properties.each(&:udprn)
      udprns = udprns.sample(batch_size/6)
      sample_properties = Uk::Property.where(udprn: udprns)
      docs = []
      sample_properties.each do |sample_property|
        beds = beds_sample.sample
        baths = baths_sample.sample
        receptions = receptions_sample.sample
        property_type = property_type_sample.sample
        property_status_type_sample = random.rand(1..100)
        if property_status_type_sample >= 1 && property_status_type_sample <= 6
          property_status_type = "Green"
        elsif property_status_type_sample >= 7 && property_status_type_sample <= 30
          property_status_type = "Amber"
        elsif property_status_type_sample >= 31 && property_status_type_sample <= 100
          property_status_type = "Red"
        end
        sale_price_sample = random.rand(100000..10000000)
        dream_price_sample = random.rand(100000..10000000)
        current_valuation_sample = random.rand(100000..10000000)
        doc = {
          udprn: sample_property.udprn,
          beds: beds,
          baths: baths,
          receptions: receptions,
          property_type: property_type,
          property_status_type: property_status_type
        }
        if property_status_type == "Green"
          doc[:sale_price] = sale_price_sample
          doc[:current_valuation] = current_valuation_sample
        elsif property_status_type == "Amber"
          doc[:dream_price] = dream_price_sample
          doc[:current_valuation] = current_valuation_sample
        else
          doc[:dream_price] = dream_price_sample
        end

        #### Address and postcode units
        doc[:post_town] = sample_property.post_town
        doc[:county] = sample_property.county
        doc[:dependent_locality] = sample_property.dl
        doc[:throroughfare_description] = sample_property.td
        doc[:dependent_throroughfare_description] = sample_property.dtd
        doc[:district] = sample_property.district
        doc[:sector] = sample_property.parsed_sector
        doc[:postcode] = sample_property.postcode
        doc[:unit] = sample_property.postcode
        doc[:area] = sample_property.district.match(/([A-Z]+)/)[0]
        docs << {index: {_index: Rails.configuration.address_index_name_load_testing, _type: Rails.configuration.address_type_name_load_testing, _id: sample_property.udprn}}
        docs << doc
      end
      bulk_update_adresses(docs)
    end
  end

end
