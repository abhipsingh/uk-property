class Events::Track < ActiveRecord::Base
  default_scope { where(active: true) }

  attr_accessor :details
  ADDRESS_ATTRS = [:property, :locality, :street]
  TRACKING_TYPE_MAP = {
    property_tracking: 1,
    locality_tracking: 2,
    street_tracking: 3,
  }
  REVERSE_TRACKING_TYPE_MAP = TRACKING_TYPE_MAP.invert

  def full_details
    return @details if @details
    @details = PropertyDetails.details(udprn)['_source']
  end

  def self.locality_hash(details)
    "@_#{details[:post_town]}_#{details[:dependent_locality]}_@_@_@_@_@_@|@_@_#{details[:district]}"
  end

  def self.td_hash(details)
   "@_#{details[:post_town]}_#{details[:dependent_locality]}_#{details[:thoroughfare_description]}_@_@_@_@_@|@_@_#{details[:district]}"
  end

  def self.dtd_hash(details)
   "@_#{details[:post_town]}_#{details[:dependent_locality]}_@_#{details[:dependent_thoroughfare_description]}_@_@_@_@|@_@_#{details[:district]}"
  end

  def self.street_hash(details)
    if details[:thoroughfare_description]
      td_hash(details)
    elsif details[:dependent_thoroughfare_description]
      dtd_hash(details)
    else
      nil
    end
  end

  def self.property_hash(details)
   "@_@_@_@_@_@_@_@_#{details[:udprn]}"
  end
end

