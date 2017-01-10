module Agents
  module Branches
    class AssignedAgent < ActiveRecord::Base
      has_secure_password

      has_many :quotes, class_name: 'Agents::Branches::AssignedAgents::Quote', foreign_key: 'agent_id'
      has_many :leads, class_name: 'Agents::Branches::AssignedAgents::Lead', foreign_key: 'agent_id'

      belongs_to :branch

      ##### All recent quotes for the agent being displayed
      ##### Data being fetched from this function
      ##### Example run the following in irb
      ##### Agents::Branches::AssignedAgent.last.recent_properties_for_quotes
      def recent_properties_for_quotes(payment_terms_params=nil, service_required_param=nil, status_param=nil, search_str=nil)
        results = []

        # udprns = quotes.where(district: self.branch.district).order('created_at DESC').pluck(:property_id)
        query = quotes
        query = query.search_address_and_vendor_details(search_str) if search_str
        udprns = query.order('created_at DESC').pluck(:property_id).uniq

        search_params = {
          sort_order: 'desc',
          sort_key: 'status_last_updated',
          udprns: udprns
        }
        api = PropertyDetailsRepo.new(filtered_params: search_params)
        api.apply_filters

        body, status = api.fetch_data_from_es
        if status.to_i == 200
          body.each do |property_details|

            ### Payment terms params filter
            next if payment_terms_params && payment_terms_params != property_details['payment_terms']

            ### Services required filter
            next if service_required_param && service_required_param != property_details['service_required']

            ### Quotes status filter
            property_id = property_details['udprn'].to_i
            quotes = self.quotes.where(property_id: property_id).where('created_at > ?', 1.year.ago)
            quote_status = Agents::Branches::AssignedAgents::Quote::REVERSE_STATUS_HASH[quotes.last.status]
            next if status_param && status_param != quote_status

            new_row = {}
            new_row[:udprn] = property_id
            if quotes.count > 0
              new_row[:submittted_on] = quotes.last.created_at.to_s
              new_row[:status] = quote_status
              new_row[:status] ||= 'PENDING'
            else
              new_row[:submittted_on] = nil
              new_row[:status] = 'PENDING'
            end
            new_row[:activated_on] = property_details['status_last_updated']
            new_row[:type] = 'SALE'
            new_row[:photo_url] = property_details['photos'][0]
            new_row[:street_view_url] = property_details['street_view_image_url']
            new_row[:address] = PropertyDetails.address(property_details)


            ### Price details starts
            if property_details['status'] == 'Green'
              keys = ['asking_price', 'offers_price', 'fixed_price']
              
              keys.select{ |t| property_details.has_key?(t) }.each do |present_key|
                new_row[present_key] = property_details[present_key]
              end
                
            else
              new_row[:latest_valuation] = property_details['current_valuation'][0]
            end
            ### Price details ends

            ### Historical prices
            property_historical_prices = PropertyHistoricalDetail.where(udprn: "#{property_id}").order("date DESC").pluck(:price)
            new_row[:historical_prices] = property_historical_prices
            if quotes.last && quotes.last.status == Agents::Branches::AssignedAgents::Quote::STATUS_HASH['Won']
              vendor = Vendor.where(property_id: property_id).where(status: Vendor::STATUS_HASH['Verified']).first
              new_row[:vendor_name] = vendor.full_name
              new_row[:vendor_email] = vendor.email
              new_row[:vendor_mobile] = vendor.mobile
              new_row[:vendor_image_url] = nil
            else
              new_row[:vendor_name] = nil
              new_row[:vendor_email] = nil
              new_row[:vendor_mobile] = nil
              new_row[:vendor_image_url] = nil
            end

            ### Branch and logo
            new_row[:assigned_branch_logo] = self.branch.image_url
            new_row[:assigned_branch_name] = self.branch.name


            new_row[:property_type] = property_details['property_type']
            new_row[:beds] = property_details['beds']
            new_row[:baths] = property_details['baths']
            new_row[:receptions] = property_details['receptions']
            new_row[:floor_plan_url] = property_details['floor_plan_url']
            new_row[:current_agent] = self.name
            new_row[:service_required] = property_details['service_required']
            new_row[:verification_status] = property_details['verification_status']

            new_row[:payment_terms] = self.quotes.last.payment_terms
            new_row[:quotes] = property_details['quotes']

            new_row[:quotes_received] = Agents::Branches::AssignedAgents::Quote.where(property_id: property_id).where('created_at > ?', 1.week.ago).count

            #### WINNING AGENT
            winning_quote = Agents::Branches::AssignedAgents::Quote.where(status: Agents::Branches::AssignedAgents::Quote::REVERSE_STATUS_HASH['Won'], property_id: property_id).first
            if winning_quote
              new_row[:winning_agent] = winning_quote.agent.name
              new_row[:quote_price] = winning_quote.compute_price
              new_row[:deadline] = winning_quote.created_at.to_s 
              new_row[:quote_accepted] = true
            else
              new_row[:winning_quote] = nil
              new_row[:quote_price] = nil
              new_row[:deadline] = Time.at(Time.parse(property_details['status_last_updated']) + 48.hours - Time.now).utc.strftime "%H:%M:%S"
              new_row[:quote_accepted] = false
            end

            results.push(new_row)

          end
        end
        results
      end


      ##### All leads for agents will be fetched using this method
      #### To try this in console
      #### Agents::Branches::AssignedAgent.last.recent_properties_for_claim
      #### New properties udprns for testing 
      #### 4745413, 4745410, 4745409, 4745408, 4745399
      #### To test this function, create the following lead.
      #### Agents::Branches::AssignedAgents::Lead.create(district: "CH45", property_id: 4745413, vendor_id: 1)
      #### Then call the following function for the agent in that district
      def recent_properties_for_claim(status=nil)
        district = self.branch.district
        query = Agents::Branches::AssignedAgents::Lead.where(district: district).where('created_at > ?', 1.year.ago)
        if status == 'New'
          query = query.where(agent_id: nil)
        elsif status == 'Won'
          query = query.where(agent_id: self.id)
        elsif status == 'Lost'
          query = query.where.not(agent_id: self.id).where.not(agent_id: nil)
        end
        leads = query.order('created_at DESC').limit(20)
        results = []

        leads.each do |lead|
          new_row = {}
          #### Submitted on
          new_row[:submittted_on] = (lead.agent_id != self.id) ? "Not yet claimed by you" : lead.updated_at.to_s

          ### address of the property
          details = PropertyDetails.details(lead.property_id)
          details = details['_source']
          new_row[:address] = PropertyDetails.address(details)

          ### Property type
          new_row[:property_type] = details['property_type']

          ### Street image url
          new_row[:street_view_url] = details['street_view_url']

          #### Udprn of the property
          new_row[:udprn] = details['udprn']

          ### Picture
          new_row[:photo_url] = details['photos'][0]

          ### beds
          new_row[:beds] = details['beds']

          ### dream price
          new_row[:baths] = details['baths']

          ### receptions
          new_row[:receptions] = details['receptions']

          ### dream_price
          new_row[:dream_price] = details['dream_price']

          ### last sale price
          new_row[:last_sale_prices] = PropertyHistoricalDetail.where(udprn: details['udprn']).order('date DESC').pluck(:price)

          #### Vendor details
          if lead.agent_id == self.id
            vendor = Vendor.where(id: lead.vendor_id).first
            new_row[:vendor_name] = vendor.full_name
            new_row[:vendor_email] = vendor.email
            new_row[:vendor_mobile] = vendor.mobile
            new_row[:vendor_image_url] = vendor.image_url
          else
            new_row[:vendor_name] = nil
            new_row[:vendor_email] = nil
            new_row[:vendor_mobile] = nil
            new_row[:vendor_image_url] = nil
          end

          ### Deadline
          if lead.agent_id.nil?
            new_row[:deadline] = Time.at(lead.created_at + 24.hours - Time.now).utc.strftime "%H:%M:%S"
            new_row[:claimed] = false
          else
            new_row[:deadline] = lead.updated_at.to_s
            new_row[:claimed] = true
          end

          ### Winning agent name
          if !lead.agent_id.nil?
            new_row[:winning_agent] = lead.agent.name
            new_row[:branch_logo] = lead.agent.branch.image_url
            new_row[:branch_name] = lead.agent.branch.name
          else
            new_row[:winning_agent] = nil
            new_row[:branch_logo] = nil
            new_row[:branch_name] = nil
          end


          ### Status of the link
          if lead.agent_id == self.id
            new_row[:status] = 'Won'
          elsif lead.agent_id.nil?
            new_row[:status] = 'New'
          else
            new_row[:status] = 'Lost'
          end

          ### Verified or not
          if new_row[:status] == 'Won'
            
          end

          results.push(new_row)
            
        end

        results
      end

      def active_properties
        quotes.where(status: Agents::Branches::AssignedAgents::Quote::STATUS_HASH['New']).count
      end

      def self.from_omniauth(auth)
        new_params = auth.as_json.with_indifferent_access
        user_details = nil
        Rails.logger.info(new_params)
        where(new_params.slice(:provider, :uid)).first_or_initialize.tap do |user|
          user.provider = new_params['provider']
          user.uid = new_params['uid']
          user.name = new_params['info']['name']
          user.email = new_params['info']['email']
          user.image_url = "http://graph.facebook.com/#{new_params['uid']}/picture?type=large"
          user.oauth_token = new_params['credentials']['token']
          user.oauth_expires_at = Time.at(new_params['credentials']['expires_at'])
          user_details = user
        end
        user_details
      end
    end
  end
end
