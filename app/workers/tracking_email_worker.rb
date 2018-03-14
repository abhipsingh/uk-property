class TrackingEmailWorker
  include Sidekiq::Worker
  sidekiq_options :retry => false

  def perform(update_hash, details)

    ### Get all buyers which are tracking this property
    details = details.with_indifferent_access
    udprn = details[:udprn]
    property_tracking_buyer_details = Events::Track.where(udprn: udprn, type_of_tracking: Events::Track::TRACKING_TYPE_MAP[:property_tracking])
                                                   .select([:buyer_id, :created_at, :type_of_tracking])
    property_tracking_buyer_hash = property_tracking_buyer_details.reduce({}) { |acc_hash, hash| acc_hash.merge(hash.buyer_id => hash)}
    property_tracking_buyer_ids = property_tracking_buyer_details.map(&:buyer_id)

    ### Get all buyers who are interested in this street, matching their property requirements
    hash_str = Events::Track.send("street_hash", details)
    street_tracking_buyer_details = Events::Track.where(type_of_tracking: Events::Track::TRACKING_TYPE_MAP[:street_tracking])
                                                 .where(hash_str: hash_str)
                                                 .select([:buyer_id, :created_at, :type_of_tracking])
    street_tracking_buyer_hash = street_tracking_buyer_details.reduce({}) { |acc_hash, hash| acc_hash.merge(hash.buyer_id => hash)}
    street_tracking_buyer_ids = street_tracking_buyer_details.map(&:buyer_id)


    ### Get all buyers who are interested in this locality, matching their property requirements
    hash_str = Events::Track.send("locality_hash", details)
    locality_tracking_buyer_details = Events::Track.where(type_of_tracking: Events::Track::TRACKING_TYPE_MAP[:locality_tracking])
                                                   .where(hash_str: hash_str)
                                                   .select([:buyer_id, :created_at, :type_of_tracking])
    locality_tracking_buyer_hash = locality_tracking_buyer_details.reduce({}) { |acc_hash, hash| acc_hash.merge(hash.buyer_id => hash)}
    locality_tracking_buyer_ids = locality_tracking_buyer_details.map(&:buyer_id)

    ### Get buyer details of the buyers who matching property requirements of property and who
    ### are tracking locality and street and buyers who are directly tracking this property
    buyers = PropertyBuyer.where("(id IN (?) AND min_beds <= ? AND max_beds >= ? AND min_baths <= ? AND max_baths >= ? AND min_receptions <= ? AND max_receptions >= ? AND ? = ANY(property_types)) OR id IN (?) ", (street_tracking_buyer_ids + locality_tracking_buyer_ids), details[:beds].to_i, details[:beds].to_i, details[:baths].to_i, details[:baths].to_i, details[:receptions].to_i, details[:receptions].to_i, details[:property_type], property_tracking_buyer_ids )
                          .select([:first_name, :last_name, :email, :id]).to_a
    Rails.logger.info("hello__#{buyers}")
    buyers.each do |buyer|
      #if details[:percent_completed].to_i == 100 && details[:agent_id].to_i != 0
        matching_hash = property_tracking_buyer_hash[buyer.id] || street_tracking_buyer_hash[buyer.id] || locality_tracking_buyer_hash[buyer.id]
        tracking_date = matching_hash[:created_at]
        type_of_tracking = Events::Track::REVERSE_TRACKING_TYPE_MAP[matching_hash[:type_of_tracking]]
        buyer.send_email_for_a_matching_property(details, tracking_date, type_of_tracking, buyer.id, update_hash)
      #end
    end
  end
end

