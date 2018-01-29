module EnquiryInfoHelper
  extend ActiveSupport::Concern

  included do
  end

  def filtered_agent_query(agent_id: id, search_str: str=nil, last_time: time=nil, is_premium: premium=false, buyer_id: buyer=nil, type_of_match: match=nil, is_archived: archived=nil, closed: is_closed=nil)
    query = Event.where(agent_id: agent_id)
    parsed_last_time = Time.parse(last_time) if last_time
    query = query.where("created_at > ? ", parsed_last_time) if last_time
    query = query.unscope(where: :is_archived).where(is_archived: true) if is_archived.to_s == "true" && is_premium
    query = query.where(type_of_match: Event::TYPE_OF_MATCH[type_of_match.to_s.downcase.to_sym]) if type_of_match
    query = query.where(buyer_id: buyer_id) if buyer_id && is_premium
    query = query.where(stage: [Event::EVENTS[:closed_won_stage], Event::EVENTS[:closed_lost_stage]]) if closed
    udprns = []
    if search_str && is_premium
      res = query.to_a
      res_udprns = res.map(&:udprn).uniq
      udprns = self.class.fetch_udprns(search_str, res_udprns)
      query = query.where(udprn: udprns) if search_str && is_premium
    end

    query
  end

  def rank(hash, key)
    sorted_values = hash.values.sort.reverse
    key_value = hash[key]
    index = sorted_values.index(key_value)
    run = rank = 0
    last_n = nil

    ranked = sorted_values.map do |n|
      run += 1
      next rank if n == last_n
      last_n = n
      rank += run
      run = 0
      rank
    end

    ranked[index.to_i].to_i
  end

  module ClassMethods

    ### Fetch udprns corresponding to the hash_str for any property
    def fetch_udprns(hash_str, udprns=[], property_status_type=nil, verification_status=nil)
      hash_val = { hash_str: hash_str }
      PropertySearchApi.construct_hash_from_hash_str(hash_val)
      if hash_val[:udprn]
        [hash_val[:udprn]]      
      elsif !udprns.empty?
        hash_val[:udprns] = udprns.map(&:to_s).join(',')
        hash_val[:hash_str] = hash_str
        hash_val[:property_status_type] = property_status_type if property_status_type
        hash_val[:verification_status] = verification_status if verification_status
        hash_val[:hash_type] = 'Text'
        api = PropertySearchApi.new(filtered_params: hash_val)
        api.modify_filtered_params
        api.apply_filters
        api.increase_size_filter
        udprns, status = api.fetch_udprns 
        
        ### If the status is 200
        if status.to_i == 200
          udprns.map(&:to_i)
        else
          []
        end

      else
        hash_val[:hash_type] = 'Text'
        #hash_val.delete(:hash_str)
        hash_val[:property_status_type] = property_status_type if property_status_type
        hash_val[:verification_status] = verification_status if verification_status
        api = PropertySearchApi.new(filtered_params: hash_val)
        api.modify_filtered_params
        api.apply_filters
        api.increase_size_filter
        udprns, status = api.fetch_udprns 
        if status.to_i == 200
          udprns.map(&:to_i)
        else
          []
        end
      end

    end


    ### Process result of all enquiries
    def process_enquiries_result(arr_rows=[], agent_id=nil, is_premium=false, old_stats_flag=false)
      buyer_ids = []
      result = []
      arr_rows.each_with_index do |each_row, index|
        new_row = {}
        new_row[:id] = each_row.id
        new_row[:udprn] = each_row.udprn
        new_row[:received] = each_row.created_at
        new_row[:type_of_enquiry] = Event::REVERSE_EVENTS[each_row.event]
        new_row[:time_of_event] = each_row.created_at.to_time.to_s
        new_row[:buyer_id] = each_row.buyer_id
        new_row[:type_of_match] = Event::REVERSE_TYPE_OF_MATCH[each_row.type_of_match]
        new_row[:scheduled_visit_time] = each_row.scheduled_visit_time
        property_id = each_row.udprn
        push_property_details_row(new_row, property_id)
        add_tracking_details_to_enquiry_row(new_row, property_id, each_row, agent_id, 'Sale')
        new_row[:stage] = Event::REVERSE_EVENTS[each_row.stage]
        new_row[:hotness] = Event::REVERSE_EVENTS[each_row.rating]
        new_row[:offer_date] = each_row.offer_date
        new_row[:offer_price] = each_row.offer_price

        ### If the property is closed won, include the details of the new buyer as well
        #Rails.logger.info("hello_#{each_row.udprn}")
        if each_row.stage == Event::EVENTS[:closed_won_stage]
          sold_property = SoldProperty.where(udprn: each_row.udprn).last
          if sold_property
            new_row[:final_price] = sold_property.sale_price 
            new_buyer = PropertyBuyer.where(id: sold_property.buyer_id)
                                     .select([:id, :email, :first_name, :last_name, :mobile, :status, :chain_free, :funding, 
                                              :biggest_problems, :buying_status, :budget_to, :budget_from,
                                              :first_name, :last_name, :image_url, :property_types])
                                     .last
    
            if new_buyer
    
              new_buyer.as_json.each do |key, value|
                new_key = 'new_vendor_' + key.to_s
                new_row[new_key.to_sym] = value
              end
    
            end
            new_row[:actual_completion_date] = sold_property.completion_date
          end

        end
        new_row[:actual_completion_date] ||= nil
        new_row[:final_price] ||= nil
        new_row[:expected_completion_date] = each_row.expected_completion_date
        buyer_ids.push(each_row.buyer_id)
        result.push(new_row)
      end

      buyers = PropertyBuyer.where(id: buyer_ids).select([:id, :email, :first_name, :last_name, :mobile, :status, :chain_free, :funding, 
                                                          :biggest_problems, :buying_status, :budget_to, :budget_from,
                                                          :first_name, :last_name, :image_url, :property_types])
                            .order("position(id::text in '#{buyer_ids.join(',')}')")

      buyer_hash = {}

      buyers.each { |buyer| buyer_hash[buyer.id] = buyer }
      result.each { |row| add_buyer_details(row, buyer_hash, is_premium, old_stats_flag) }
      result
    end

    ### Add buyer details to the enquiry rows
    def add_buyer_details(details, buyer_hash, is_premium=false, old_stats_flag=false)
      buyer_id = details[:buyer_id]
      buyer = buyer_hash[buyer_id]
      if buyer_id && buyer_hash[buyer_id]
        details[:buyer_status] = Event::REVERSE_STATUS_TYPES[buyer_hash[buyer_id].status] rescue nil
        details[:buyer_full_name] = buyer_hash[buyer_id].first_name + ' ' + buyer_hash[buyer_id].last_name rescue ''
        details[:buyer_image] = buyer_hash[buyer_id].image_url
        details[:buyer_email] = buyer_hash[buyer_id].email
        details[:buyer_mobile] = buyer_hash[buyer_id].mobile
        details[:chain_free] = buyer_hash[buyer_id].chain_free
        details[:buyer_funding] = PropertyBuyer::REVERSE_FUNDING_STATUS_HASH[buyer_hash[buyer_id].funding] rescue nil
        details[:buyer_biggest_problems] = buyer[:biggest_problems]
        details[:buyer_property_types] = buyer[:property_types]
        details[:buyer_buying_status] = PropertyBuyer::REVERSE_BUYING_STATUS_HASH[buyer_hash[buyer_id].buying_status] rescue nil
        details[:buyer_budget_from] = buyer_hash[buyer_id].budget_from
        details[:buyer_budget_to] = buyer_hash[buyer_id].budget_to
        details[:views] = buyer_view_ratio(buyer_id, details[:udprn], is_premium, old_stats_flag)
        details[:enquiries] = buyer_enquiry_ratio(buyer_id, details[:udprn], is_premium, old_stats_flag)
      else
        keys = [ :buyer_status, :buyer_full_name, :buyer_image, :buyer_email, :buyer_mobile, :chain_free, :buyer_funding, 
                 :buyer_biggest_problems, :buyer_buying_status, :buyer_budget_from, :buyer_budget_to, :buyer_property_types,
                 :views, :enquiries]
        keys.each { |key| details[key] = nil }
      end
    end

    def buyer_view_ratio(buyer_id, udprn, is_premium=false, old_stats_flag=false)
      property_views = buyer_views = nil

      if !is_premium
        buyer_views = Events::View.where(udprn: udprn).where(buyer_id: buyer_id).count
        property_views = Events::EnquiryStatProperty.new(udprn: udprn).views
      elsif old_stats_flag
        buyer_views = Events::View.where(udprn: udprn).unscope(where: :is_archived).where(buyer_id: buyer_id).count
        unarchived_property_views = Events::EnquiryStatProperty.new(udprn: udprn).views
        archived_property_views = Events::ArchivedStat.new(udprn: udprn).views
        property_views = unarchived_property_views + archived_property_views
      else
        buyer_views = Events::View.where(udprn: udprn).where(buyer_id: buyer_id).count
        property_views = Events::EnquiryStatProperty.new(udprn: udprn).views
      end

      buyer_views.to_s + '/' + property_views.to_s
    end

    def buyer_enquiry_ratio(buyer_id, udprn, is_premium=false, old_stats_flag=false)
      property_enquiries = buyer_enquiries = nil

      if !is_premium
        buyer_enquiries = Event.where(buyer_id: buyer_id).where(udprn: udprn).count
        property_enquiries = Events::EnquiryStatProperty.new(udprn: udprn).enquiries
      elsif old_stats_flag
        buyer_enquiries = Event.where(buyer_id: buyer_id).unscope(where: :is_archived).where(udprn: udprn).count
        unarchived_property_enquiries = Events::EnquiryStatProperty.new(udprn: udprn).enquiries
        archived_property_enquiries = Events::ArchivedStat.new(udprn: udprn).enquiries
        property_enquiries = unarchived_property_enquiries + archived_property_enquiries
      else
        buyer_enquiries = Event.where(buyer_id: buyer_id).where(udprn: udprn).count
        property_enquiries = Events::EnquiryStatProperty.new(udprn: udprn).enquiries
      end

      buyer_enquiries.to_s + '/' + property_enquiries.to_s
    end

    ### For every enquiry row, extract the info from details hash and merge it
    ### with new row
    def push_property_enquiry_details_buyer(new_row, details)
      attrs = [:address, :price, :dream_price, :current_valuation, :pictures, :street_view_image_url, :sale_prices, :property_status_type, 
               :verification_status, :vanity_url, :assigned_agent_id, :assigned_agent_image_url, :assigned_agent_mobile,
               :assigned_agent_email, :assigned_agent_title, :dependent_locality, :thoroughfare_description, :post_town, :agent_id,
               :beds, :baths, :receptions, :assigned_agent_first_name, :assigned_agent_last_name, :percent_completed]
      new_row.merge!(details.slice(*attrs))
      new_row[:image_url] = new_row[:street_view_image_url] || details[:pictures].first rescue nil
      if new_row[:image_url].nil?
        # image_url = process_image(details) if Rails.env != 'test'
        image_url ||= "https://s3.ap-south-1.amazonaws.com/google-street-view-prophety/#{details['udprn']}/fov_120_#{details['udprn']}.jpg"
        new_row[:street_view_image_url] = image_url
      end
      new_row[:status] = new_row[:property_status_type]
      new_row[:percent_completed] ||= PropertyService.new(details[:udprn]).compute_percent_completed({}, details)
    end

    def push_property_details_row(new_row, property_id)
      details =  PropertyDetails.details(property_id)['_source']
      push_property_enquiry_details_buyer(new_row, details)
    end

    def add_tracking_details_to_enquiry_row(new_row, property_id, event_details, agent_id, property_for='Sale')
      #### Tracking property or not
      tracking_property_event = Events::Track::TRACKING_TYPE_MAP[:property_tracking]
      buyer_id = new_row[:buyer_id]
      qualifying_stage_query = Events::Stage
      tracking_query = nil
      tracking_result = Events::Track.where(buyer_id: buyer_id).where(type_of_tracking: tracking_property_event).where(udprn: property_id).select(:id).first
      new_row[:property_tracking] = (tracking_result.nil? ? false : true)
      new_row
    end


    def add_enquiry_stats(new_row, details, is_premium=false, old_stats_flag=false)
      table = ''
      #Rails.logger.info(details)
      property_id = details['udprn']
      Rails.logger.info("hello start #{Time.now.to_f}") 
      if old_stats_flag && is_premium
        unarchived_property_stat = Events::EnquiryStatProperty.new(udprn: property_id)
        archived_property_stat = Events::ArchivedStat.new(udprn: property_id)

        ### Total Visits for premium users
        new_row['total_visits'] = archived_property_stat.views + unarchived_property_stat.views
        new_row['total_enquiries'] = archived_property_stat.enquiries + unarchived_property_stat.enquiries
        new_row['requested_viewing'] = archived_property_stat.specific_enquiry_count(:requested_viewing) + unarchived_property_stat.specific_enquiry_count(:requested_viewing)
        new_row['requested_message'] = archived_property_stat.specific_enquiry_count(:requested_message) + unarchived_property_stat.specific_enquiry_count(:requested_message)
        new_row['requested_callback'] = archived_property_stat.specific_enquiry_count(:requested_callback) + unarchived_property_stat.specific_enquiry_count(:requested_callback)
        new_row['interested_in_making_an_offer'] = archived_property_stat.specific_enquiry_count(:interested_in_making_an_offer) + unarchived_property_stat.specific_enquiry_count(:interested_in_making_an_offer)
        new_row['interested_in_viewing'] = archived_property_stat.specific_enquiry_count(:interested_in_viewing) + unarchived_property_stat.specific_enquiry_count(:interested_in_viewing)
        new_row['deleted'] = Events::IsDeleted.where(udprn: property_id).count
        new_row['offer_made_stage'] = Event.unscope(where: :is_developer).where(udprn: property_id).where(stage: EVENTS[:offer_made_stage]).count
        new_row['trackings'] = Events::Track.where(udprn: property_id).count 
      else
        property_stat = Events::EnquiryStatProperty.new(udprn: property_id)
        new_row['total_visits'] = property_stat.views
        new_row['total_enquiries'] = property_stat.enquiries
        new_row['requested_viewing'] = property_stat.specific_enquiry_count(:requested_viewing)
        new_row['requested_message'] = property_stat.specific_enquiry_count(:requested_message)
        new_row['requested_callback'] = property_stat.specific_enquiry_count(:requested_callback)
        new_row['interested_in_making_an_offer'] = property_stat.specific_enquiry_count(:interested_in_making_an_offer)
        new_row['interested_in_viewing'] = property_stat.specific_enquiry_count(:interested_in_viewing) 
        #new_row['offer_made_stage'] = Event.where(udprn: property_id).where(stage: Event::EVENTS[:offer_made_stage]).count
        Rails.logger.info("hello end #{Time.now.to_f}") 

        ### Last sold property date
        sold_property = SoldProperty.where(udprn: property_id).select([:completion_date]).last
        if sold_property && sold_property.completion_date
          completion_date = sold_property.completion_date
          new_row['deleted'] = Events::IsDeleted.where('created_at > ?', completion_date).where(udprn: property_id).count
          new_row['trackings'] = Events::Track.where('created_at > ?', completion_date).where(udprn: property_id).count 
        else
          new_row['deleted'] = Events::IsDeleted.where(udprn: property_id).count
          new_row['trackings'] = Events::Track.where(udprn: property_id).count 
        end
      end

    end

  end

end
