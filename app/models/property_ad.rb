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
  PRICE = {
    'Featured' => 2,
    'Premium' => 1
  }
  ALL_LOCALITY_LEVELS = [ :county, :post_town, :dependent_locality, :thoroughfare_description, :dependent_thoroughfare_description ]
  ALL_POSTCODE_LEVELS = [ :unit, :sector, :district ]

  REVERSE_TYPE_HASH = TYPE_HASH.invert

  def self.ads_info_all_address_levels(response, udprn, property_for='Sale')
    service = SERVICE[property_for]
    details = PropertyDetails.details(udprn.to_i)['_source']
    details = details.with_indifferent_access
    types = ['Featured', 'Premium']
    udprn = details['udprn'].to_i
    levels_arr = []
    types.each do |each_type|
      new_details = details.deep_dup.with_indifferent_access
      ALL_LOCALITY_LEVELS.each{|t| assign_null(new_details, t) }
      ALL_LOCALITY_LEVELS.each do |each_locality_level|
        hash_str = MatrixViewService.form_hash_str(new_details, each_locality_level)
        response["#{each_locality_level.to_s}"] = details[each_locality_level]
        response["#{each_locality_level.to_s}_hash"] = hash_str if details[each_locality_level] &&   !details[each_locality_level].empty?
        response["#{each_locality_level.to_s}_#{each_type.downcase}_count"] = MAX_ADS_HASH[each_type] - PropertyAd.where(hash_str: hash_str).where(ad_type: TYPE_HASH[each_type]).where(service: service).count  if details[each_locality_level] &&  !details[each_locality_level.to_s].empty?
        response["#{each_locality_level.to_s}_#{each_type.downcase}_booked"] = PropertyAd.where(hash_str: hash_str).where(ad_type: TYPE_HASH[each_type]).where(service: service).where(property_id: udprn).select([:id, :expiry_at]).first  if  details[each_locality_level] &&   !details[each_locality_level.to_s].empty?
        response["#{each_locality_level.to_s}_#{each_type.downcase}_oldest_booked"] = PropertyAd.where(hash_str: hash_str).where(ad_type: TYPE_HASH[each_type]).where(service: service).order('expiry_at ASC').first.expiry_at rescue nil  if details[each_locality_level] &&   !details[each_locality_level.to_s].empty?
       response[:price_per_slot] = PRICE[each_type]
      end
      ALL_POSTCODE_LEVELS.each do |each_postcode_unit|
        hash_str = MatrixViewService.form_hash(new_details, each_postcode_unit)
        response["#{each_postcode_unit.to_s}"] = details[each_postcode_unit]
        response["#{each_postcode_unit.to_s}_hash"] = hash_str
        response["#{each_postcode_unit.to_s}_#{each_type.downcase}_count"] = MAX_ADS_HASH[each_type] - PropertyAd.where(hash_str: hash_str).where(service: service).where(ad_type: TYPE_HASH[each_type]).count
        response["#{each_postcode_unit.to_s}_#{each_type.downcase}_booked"] = PropertyAd.where(hash_str: hash_str).where(ad_type: TYPE_HASH[each_type]).where(property_id: udprn).where(service: service).select([:id, :expiry_at]).first
        response["#{each_postcode_unit.to_s}_#{each_type.downcase}_oldest_booked"] = PropertyAd.where(hash_str: hash_str).where(ad_type: TYPE_HASH[each_type]).where(service: service).order('created_at ASC').first.expiry_at rescue nil
        response[:price_per_slot] = PRICE[each_type]
      end
    end
  end

  def self.hash_at_level(level, details)
    hash = nil
    if level == :dependent_locality
      hash = "@_#{details['post_town']}_#{details['dependent_locality']}_@_@_@_@_@_@|@_@_#{details['district']}"
    elsif level == :dependent_thoroughfare_description
      hash = "@_#{details['post_town']}_#{details['dependent_locality']}_@_#{details['dependent_thoroughfare_description']}_@_@_@_@|@_@_#{details['district']}"
    elsif level == :thoroughfare_description
      hash = "@_#{details['post_town']}_#{details['dependent_locality']}_#{details['thoroughfare_description']}_@_@_@_@_@|@_@_#{details['district']}"
    elsif level == :post_town
      hash = "#{details['county']}_#{details['post_town']}_@_@_@_@_@_@_@_@"
    elsif level == :county
      hash = "#{details['county']}_@_@_@_@_@_@_@_@_@"
    elsif level == :sector
      hash = "@_@_#{details['dependent_locality']}_@_@_@_@_@_@|@_#{details['sector']}_@"
    elsif level == :district
      hash = "@_#{details['post_town']}_@_@_@_@_@_@_@|@_@_#{details['district']}"
    elsif level == :unit
      hash = "@_@_@_@_@_@_@_@_@|#{details['unit']}_@_@"
    end
    hash
  end

  def self.assign_null(hash, key)
    val = hash[key]
    val = '@' if val.nil? || val.empty?
    hash[key] = val
  end

end
