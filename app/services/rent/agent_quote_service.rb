module Rent
  class AgentQuoteService
    S3_BASE_URL = "https://s3.ap-south-1.amazonaws.com/google-street-view-prophety/"
    
    attr_accessor :agent_id, :agent
  
    def initialize(agent: agent_details)
      @agent_id = agent.id
      @agent = agent
    end

    PAGE_SIZE = 20
 
    ##### All recent quotes for the agent being displayed
    ##### Data being fetched from this function
    ##### Example run the following in irb
    ##### Agents::Branches::AssignedAgent.last.recent_properties_for_quotes
    def recent_properties_for_quotes(payment_terms_params=nil, status_param=nil, is_premium=false, page_number=0, count=false, latest_time=nil)
      results = []

      klass = Rent::Quote
      won_status = klass::STATUS_HASH['Won']
      payment_terms = klass::PAYMENT_TERMS_HASH[payment_terms_params]
      new_status = klass::STATUS_HASH['New']

      ### District of that branch
      branch = @agent.branch
      query = klass
      query = query.where(district: branch.district)
      query = query.where('created_at > ?', Time.parse(latest_time)) if latest_time
      max_hours_for_expiry = klass::MAX_VENDOR_QUOTE_WAIT_TIME

      ### 48 hour expiry deadline
      query = query.where(payment_terms: payment_terms) if payment_terms

      #### Either new quote or quotes which were won or assigned agent quote
      query = query.where("(agent_id is null and status = ? and expired = 'f' and is_assigned_agent = 'f' ) OR ( agent_id = ? and status = ? ) OR ( existing_agent_id = ? OR is_assigned_agent = 't' )", new_status, @agent_id, won_status, @agent_id)

      if status_param == 'New'
        query = query.where(agent_id: nil).where(expired: false)
      elsif status_param == 'Won'
        query = query.where(agent_id: @agent_id).where(status: won_status)
      end

      final_results = []
      results = []

      if count && is_premium
        final_results = query.count
      elsif is_premium
        results = query.order('created_at DESC')
      else
        page_number = page_number.to_i
        #Rails.logger.info(query.to_sql)
        results = query.order('created_at DESC').limit(PAGE_SIZE).offset(page_number*PAGE_SIZE)
      end

      if !count

        results.each do |each_quote|
          property_details = PropertyDetails.details(each_quote.udprn)[:_source]
          ### Quotes status filter
          property_id = property_details[:udprn].to_i
          agent_quote = nil
          quote_status = nil
          if each_quote.status == won_status
            quote_status = 'Won'
            agent_quote = Rent::Quote.where(udprn: property_id, agent_id: @agent_id).last
          elsif each_quote.status == new_status && each_quote.agent_id.nil?
            quote_status = 'New'
          end
          new_row = {}
          new_row[:id] = each_quote.id
          new_row[:udprn] = property_id
          new_row[:terms_url] = agent_quote.terms_url if agent_quote
          new_row[:terms_url] ||= each_quote.terms_url
          new_row[:submitted_on] = agent_quote.created_at.to_s if agent_quote
          new_row[:submitted_on] ||= each_quote.created_at.to_s
          new_row[:status] = quote_status
          new_row[:activated_on] = each_quote.created_at.to_s
          new_row[:photo_url] = property_details[:pictures] ? property_details[:pictures][0] : "Image not available"

          new_row[:percent_completed] = property_details[:percent_completed]
          new_row[:percent_completed] ||= PropertyService.new(property_details[:udprn]).compute_percent_completed({}, property_details)

          attrs = [ :property_type, :baths, :beds, :receptions, :floor_plan_url, :verification_status, :dream_price, :pictures, 
                    :claimed_on, :address, :vanity_url, :vendor_first_name, :vendor_last_name, :vendor_email, :vendor_mobile_number, 
                    :vendor_image_url, :assigned_agent_branch_name, :assigned_agent_branch_logo, :assigned_agent_first_name, :agent_id,
                    :assigned_agent_last_name, :property_status_type, :current_valuation, :sale_prices ]
          attrs.each {|key| new_row[key] = property_details[key] }

          new_row[:payment_terms] = nil
          new_row[:payment_terms] ||=  klass::REVERSE_PAYMENT_TERMS_HASH[agent_quote.payment_terms] if agent_quote

          new_row[:quote_price] = each_quote.price
          
          if property_details[:agent_id].to_i > 0
            new_row[:current_agent] = property_details[:assigned_agent_first_name] + ' ' + property_details[:assigned_agent_last_name]
          else
            agent_attrs = [ :current_agent, :assigned_agent_branch_logo, :assigned_agent_branch_name, :agent_id,
                            :assigned_agent_first_name, :assigned_agent_last_name ]
            agent_attrs.each { |t| new_row[t] = nil }
          end
          new_row[:street_view_url] = "#{S3_BASE_URL}#{property_details[:udprn]}/fov_120_#{property_details[:udprn]}.jpg"

          if quote_status == 'New'
            vendor_attrs = [ :vendor_id, :vendor_first_name, :vendor_last_name, :vendor_email, :vendor_mobile, :vendor_image_url ]
            vendor_attrs.each { |t| new_row[t] = nil }
          end

          ### TODO: Fix for multiple lifetimes
          new_row[:quotes_received] = klass.where(udprn: property_id).where.not(agent_id: nil).where(expired: false).count

          ### TODO: Fix for multiple lifetimes
          #### WINNING AGENT
          new_row[:status] == 'New' ? new_row[:quote_accepted] = false : new_row[:quote_accepted] = true

          new_row[:deadline] = (each_quote.created_at + klass::MAX_AGENT_QUOTE_WAIT_TIME).to_s
          new_row[:vendor_deadline_end] = (each_quote.created_at + klass::MAX_VENDOR_QUOTE_WAIT_TIME).to_s
          new_row[:vendor_deadline_start] = (each_quote.created_at + klass::MAX_AGENT_QUOTE_WAIT_TIME).to_s
          new_row[:claimed_on] = Time.parse(new_row[:claimed_on]).strftime("%Y-%m-%dT%H:%M:%SZ") if new_row[:claimed_on]
          new_row[:submitted_on] = Time.parse(new_row[:submitted_on]).strftime("%Y-%m-%dT%H:%M:%SZ") if new_row[:submitted_on]
          new_row[:deadline] = Time.parse(new_row[:deadline]).strftime("%Y-%m-%dT%H:%M:%SZ") if new_row[:deadline]
          new_row[:activated_on] = Time.parse(new_row[:activated_on]).strftime("%Y-%m-%dT%H:%M:%SZ") if new_row[:activated_on]

          final_results.push(new_row)

        end
      end
      final_results
    end

  end
end

