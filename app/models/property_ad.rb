class PropertyAd < ActiveRecord::Base
  TYPE_HASH = {
    'Premium' => 1,
    'Featured' => 2
  }

  MAX_ADS_HASH = {
    'Premium' => 20,
    'Featured' => 4
  }

  SERVICE = {
    'Sale' => 1,
    'Rent' => 2
  }

  REVERSE_TYPE_HASH = TYPE_HASH.invert

  def self.ads_info_all_address_levels(response, udprn, property_for='Sale')
    service = SERVICE[property_for]
    details = PropertyDetails.details(udprn.to_i)['_source']
    details = details.with_indifferent_access
    types = ['Featured', 'Premium']
    udprn = details['udprn'].to_i
    levels_arr = []
    all_locality_levels = [ :county, :post_town, :dependent_locality, :dependent_thoroughfare_description ]
    all_postcode_units = [ :district, :unit, :sector ]
    types.each do |each_type|
      all_locality_levels.each do |each_locality_level|
        hash_str = hash_at_level(each_locality_level, details)
        response["#{each_locality_level.to_s}"] = details[each_locality_level]
        response["#{each_locality_level.to_s}_hash"] = hash_str
        response["#{each_locality_level.to_s}_#{each_type.downcase}_count"] = MAX_ADS_HASH[each_type] - PropertyAd.where(hash_str: hash_str).where(ad_type: TYPE_HASH[each_type]).where(service: service).count
        response["#{each_locality_level.to_s}_#{each_type.downcase}_booked"] = PropertyAd.where(hash_str: hash_str).where(ad_type: TYPE_HASH[each_type]).where(service: service).where(property_id: udprn).select([:id, :created_at]).first
        response["#{each_locality_level.to_s}_#{each_type.downcase}_oldest_booked"] = PropertyAd.where(hash_str: hash_str).where(ad_type: TYPE_HASH[each_type]).where(service: service).order('created_at ASC').first.created_at rescue nil
      end
      all_postcode_units.each do |each_postcode_unit|
        hash_str = details[each_postcode_unit]
        response["#{each_postcode_unit.to_s}"] = hash_str
        response["#{each_postcode_unit.to_s}_hash"] = hash_str
        response["#{each_postcode_unit.to_s}_#{each_type.downcase}_count"] = MAX_ADS_HASH[each_type] - PropertyAd.where(hash_str: hash_str).where(service: service).where(ad_type: TYPE_HASH[each_type]).count
        response["#{each_postcode_unit.to_s}_#{each_type.downcase}_booked"] = PropertyAd.where(hash_str: hash_str).where(ad_type: TYPE_HASH[each_type]).where(property_id: udprn).where(service: service).select([:id, :created_at]).first
        response["#{each_postcode_unit.to_s}_#{each_type.downcase}_oldest_booked"] = PropertyAd.where(hash_str: hash_str).where(ad_type: TYPE_HASH[each_type]).where(service: service).order('created_at ASC').first.created_at rescue nil
      end
    end
  end

  def self.hash_at_level(level, details)
    details = details.with_indifferent_access
    all_locality_levels = [ :county, :post_town, :dependent_locality, :dependent_thoroughfare_description ]
    return details[level] if level == :county || level == :post_town
    hash_levels = []
    all_locality_levels.each do |each_locality_level|
      if each_locality_level == :county || each_locality_level == :post_town
        hash_levels = [ details[each_locality_level] ]
      else
        hash_levels.push(details[each_locality_level]) if details[each_locality_level]
      end

      break if level == each_locality_level
    end

    hash_levels.join('_')
  end
end
