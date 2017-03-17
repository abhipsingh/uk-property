module Agents
  module Branches
    class AssignedAgent < ActiveRecord::Base
      has_secure_password

      has_many :quotes, class_name: 'Agents::Branches::AssignedAgents::Quote', foreign_key: 'agent_id'
      has_many :leads, class_name: 'Agents::Branches::AssignedAgents::Lead', foreign_key: 'agent_id'

      belongs_to :branch
      attr_accessor :vendor_email, :vendor_address, :email_udprn, :verification_hash

      ##### All recent quotes for the agent being displayed
      ##### Data being fetched from this function
      ##### Example run the following in irb
      ##### Agents::Branches::AssignedAgent.last.recent_properties_for_quotes
      def recent_properties_for_quotes(payment_terms_params=nil, service_required_param=nil, status_param=nil, search_str=nil)
        results = []

        # udprns = quotes.where(district: self.branch.district).order('created_at DESC').pluck(:property_id)
        query = Agents::Branches::AssignedAgents::Quote
        query = query.where(district: self.branch.district)
        query = query.search_address_and_vendor_details(search_str) if search_str
        udprns = query.order('created_at DESC').pluck(:property_id).uniq

        search_params = {
          sort_order: 'desc',
          sort_key: 'status_last_updated',
          district: self.branch.district,
          verification_status: true
        }
        if search_params[:district] == "L37"
        #  search_params[:district] = "L14"
        end

        # search_params[:udprns] = udprns.join(',') if !udprns.empty?
        api = PropertySearchApi.new(filtered_params: search_params)
        api.apply_filters
        api.add_exists_filter(:quotes)

        body, status = api.fetch_data_from_es
        Rails.logger.info(body)
        if status.to_i == 200
          body.each do |property_details|
            next if property_details['assigned_agent_quote'] && property_details['assigned_agent_quote'] == true && property_details['agent_id'] && property_details['agent_id'] != self.id
            next if !property_details['payment_terms'] || !property_details.has_key?('services_required')
            ### Payment terms params filter
            next if payment_terms_params && payment_terms_params != property_details['payment_terms']

            ### Services required filter
            next if service_required_param && service_required_param != property_details['services_required']

            ### Quotes status filter

            property_id = property_details['udprn'].to_i

            quotes = self.quotes.where(property_id: property_id).where('created_at > ?', 1.year.ago)
            quote_status = Agents::Branches::AssignedAgents::Quote::REVERSE_STATUS_HASH[quotes.last.status] if quotes.last
            quote_status ||= 'New'
            next if status_param && status_param != quote_status

            new_row = {}
            new_row[:udprn] = property_id
            if quotes.count > 0
              new_row[:submitted_on] = quotes.last.created_at.to_s
              new_row[:status] = quote_status
              new_row[:status] ||= 'PENDING'
            else
              new_row[:submitted_on] = nil
              new_row[:status] = 'PENDING'
            end
            new_row[:activated_on] = property_details['status_last_updated']
            new_row[:type] = 'SALE'
            new_row[:photo_url] = property_details['photos'][0]
            new_row[:pictures] = property_details['pictures']
            new_row[:street_view_url] = property_details['street_view_image_url']
            new_row[:address] = PropertyDetails.address(property_details)
            new_row[:claimed_on] = property_details['claimed_at']

            ### Price details starts
            new_row[:asking_price] = property_details['asking_price']
            new_row[:offers_price] = property_details['offers_price']
            new_row[:fixed_price] = property_details['fixed_price']
            new_row[:dream_price] = property_details['dream_price']
            new_row[:latest_valuation] = property_details['current_valuation']
            ### Price details ends

            ### Historical prices
            property_historical_prices = PropertyHistoricalDetail.where(udprn: "#{property_id}").order("date DESC").pluck(:price)
            new_row[:historical_prices] = property_historical_prices

            vendor = Vendor.where(property_id: property_id).first
            if vendor.present?
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

            ### Branch and logo
            new_row[:assigned_branch_logo] = self.branch.image_url
            new_row[:assigned_branch_name] = self.branch.name
            new_row[:assigned_agent_id] = property_details['agent_id']

            new_row[:property_type] = property_details['property_type']
            new_row[:beds] = property_details['beds']
            new_row[:baths] = property_details['baths']
            new_row[:receptions] = property_details['receptions']
            new_row[:floor_plan_url] = property_details['floor_plan_url']
            new_row[:current_agent] = self.name
            new_row[:services_required] = property_details['services_required']
            new_row[:verification_status] = property_details['verification_status']

            new_row[:payment_terms] = property_details['payment_terms']
            new_row[:quotes] = property_details['quotes']

            new_row[:quotes_received] = Agents::Branches::AssignedAgents::Quote.where(property_id: property_id).where('created_at > ?', 1.week.ago).count

            #### WINNING AGENT
            winning_quote = Agents::Branches::AssignedAgents::Quote.where(status: Agents::Branches::AssignedAgents::Quote::STATUS_HASH['Won'], property_id: property_id).first
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
        query = Agents::Branches::AssignedAgents::Lead.where(district: district).where('created_at > ?', 1.week.ago)
        won_query = query
        lost_query = query
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
          if lead.agent_id && lead.agent_id != self.id
            new_row[:submitted_on] = lead.created_at + (1..5).to_a.sample.seconds
          elsif lead.agent_id
            new_row[:submitted_on] = lead.created_at.to_s
          else
            new_row[:submitted_on] = nil
          end

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
          new_row[:pictures] = details['pictures']

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
            new_row[:vendor_name] = vendor.full_name || vendor.name
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
        search_params = { limit: 100, fields: 'udprn' }
        search_params[:agent_id] = self.id
        search_params[:property_status_type] = 'Green'
        search_params[:verification_status] = true
        api = PropertySearchApi.new(filtered_params: search_params)
        api.apply_filters
        body, status = api.fetch_data_from_es
        # Rails.logger.info(body)
        body.count
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

      ### Agents::Branches::AssignedAgent.find(23).send_vendor_email("test@prophety.co.uk", 10968961)
      def send_vendor_email(vendor_email, udprn)
        salt_str = "#{vendor_email}_#{self.id}_#{self.class}"
        hash_value = BCrypt::Password.create salt_str
        hash_obj = VerificationHash.create!(email: vendor_email, hash_value: hash_value, entity_id: self.id, entity_type: self.class, udprn: udprn.to_i)
        self.verification_hash = hash_obj.hash_value
        self.vendor_email = vendor_email
        self.vendor_email = "test@prophety.co.uk"
        self.email_udprn = udprn
        details = PropertyDetails.details(udprn)['_source']
        self.vendor_address = details['address']
        VendorMailer.welcome_email(self).deliver_now
      end

    end
  end
end
