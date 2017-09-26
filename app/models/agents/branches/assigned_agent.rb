module Agents
  module Branches
    class AssignedAgent < ActiveRecord::Base
      has_secure_password

      has_many :quotes, class_name: 'Agents::Branches::AssignedAgents::Quote', foreign_key: 'agent_id'
      has_many :leads, class_name: 'Agents::Branches::AssignedAgents::Lead', foreign_key: 'agent_id'

      belongs_to :branch, class_name: 'Agents::Branch'
      attr_accessor :vendor_email, :vendor_address, :email_udprn, :verification_hash, :assigned_agent_present, :alternate_agent_email

      ### TODO: Refactoring required. Figure out a better way of dumping details of a user through a consensus
      DETAIL_ATTRS = [:id, :name, :email, :mobile, :branch_id, :title, :office_phone_number, :mobile_phone_number, :image_url, :invited_agents, :provider, :uid]

      PER_CREDIT_COST = 5
      QUOTE_CREDIT_LIMIT = -10
      LEAD_CREDIT_LIMIT = 0
      PAGE_SIZE = 30

      ##### All recent quotes for the agent being displayed
      ##### Data being fetched from this function
      ##### Example run the following in irb
      ##### Agents::Branches::AssignedAgent.last.recent_properties_for_quotes
      def recent_properties_for_quotes(payment_terms_params=nil, service_required_param=nil, status_param=nil, search_str=nil, property_for='Sale', buyer_id=nil, is_premium=false, page_number=0)
        results = []

        won_status = Agents::Branches::AssignedAgents::Quote::STATUS_HASH['Won']
        vendor = PropertyBuyer.where(id: buyer_id).select(:vendor_id).first if buyer_id
        vendor_id = vendor.vendor_id if vendor
        vendor_id ||= nil
        # udprns = quotes.where(district: self.branch.district).order('created_at DESC').pluck(:property_id)
        services_required = Agents::Branches::AssignedAgents::Quote::REVERSE_SERVICES_REQUIRED_HASH[service_required_param]
        new_status = Agents::Branches::AssignedAgents::Quote::STATUS_HASH['New']
        query = Agents::Branches::AssignedAgents::Quote
        query = query.where(district: self.branch.district)
        query = query.where('created_at > ?', 7.days.ago)
        query = query.where(vendor_id: vendor_id) if buyer_id
        query = query.where(payment_terms: payment_terms_params) if payment_terms_params
        query = query.where(service_required: services_required) if service_required_param
        
        if status_param == 'New'
          query = query.where(agent_id: nil)
        elsif status_param == 'Lost'
          query = query.where.not(agent_id: self.id).where(status: won_status)
        elsif status_param == 'Pending'
          query = query.where(agent_id: self.id).where(status: new_status)
        elsif status_param == 'Won'
          query = query.where(agent_id: self.id).where(status: won_status)
        end

        if search_str && is_premium
          udprns = Trackers::Buyer.new.fetch_udprns(search_str)
          udprns = udprns.map(&:to_i)
          query = query.where(property_id: udprns)
        end

        results = query.order('created_at DESC').limit(PAGE_SIZE).offset(page_number*PAGE_SIZE)

        results.each do |each_quote|
          property_details = PropertyDetails.details(each_quote.property_id)['_source'].with_indifferent_access
          ### Quotes status filter
          property_id = property_details['udprn'].to_i

          quote_status = nil
          if each_quote.status == won_status && each_quote.agent_id == self.id
            quote_status = 'Won'
          elsif each_quote.status == new_status && each_quote.agent_id != self.id
            quote_status = 'New'
          elsif each_quote.status == new_status && !each_quote.agent_id.nil?
            quote_status = 'Pending'
          else
            quote_status = 'Lost'
          end
          new_row = {}
          new_row[:udprn] = property_id
          if quote_status != 'Won'
            new_row[:submitted_on] = each_quote.created_at.to_s
            new_row[:status] = quote_status
          else
            new_row[:submitted_on] = nil
            new_row[:status] = 'WON'
          end
          new_row[:property_status_type] = property_details['property_status_type']
          new_row[:activated_on] = property_details['status_last_updated']
          new_row[:type] = 'SALE'
          new_row[:photo_url] = property_details['pictures'] ? property_details['pictures'][0] : "Image not available"

          new_row = new_row.merge(['property_type', 'beds', 'baths', 'receptions', 'floor_plan_url', 'services_required',
            'verification_status','asking_price','fixed_price', 'dream_price', 'pictures', 'payment_terms', 'quotes'].reduce({}) {|h, k| h[k] = property_details[k]; h })
          
          new_row[:current_agent] = self.name

          new_row[:street_view_url] = property_details['street_view_image_url']
          new_row[:address] = PropertyDetails.address(property_details)
          new_row[:claimed_on] = property_details['claimed_at']

          new_row[:latest_valuation] = property_details['current_valuation']

          ### Historical prices
          property_historical_prices = PropertyHistoricalDetail.where(udprn: "#{property_id}").order("date DESC").pluck(:price)
          new_row[:historical_prices] = property_historical_prices

          vendor = Vendor.where(property_id: property_id).first
          if vendor.present?
            new_row[:vendor_name] = vendor.name
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

          ### TODO: Fix for multiple lifetimes
          new_row[:quotes_received] = Agents::Branches::AssignedAgents::Quote.where(property_id: property_id).where.not(agent_id: nil).count

          ### TODO: Fix for multiple lifetimes
          #### WINNING AGENT
          winning_quote = Agents::Branches::AssignedAgents::Quote.where(status: Agents::Branches::AssignedAgents::Quote::STATUS_HASH['Won'], property_id: property_id).last
          if winning_quote
            new_row[:winning_agent] = winning_quote.agent.name
            new_row[:quote_price] = winning_quote.compute_price
            new_row[:deadline] = winning_quote.created_at.to_s
            new_row[:quote_accepted] = true
          else
            new_row[:winning_quote] = nil
            new_row[:quote_price] = nil
            new_row[:deadline] = Agents::Branches::AssignedAgents::Quote.where(property_id: property_id).where(agent_id: nil).first.created_at.to_time + 168.hours
            new_row[:quote_accepted] = false
          end

          results.push(new_row)

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
      def recent_properties_for_claim(status=nil, property_for='Sale', buyer_id=nil, search_str=nil, is_premium=false, page_number=0)
        district = self.branch.district
        query = Agents::Branches::AssignedAgents::Lead
        vendor = PropertyBuyer.where(id: buyer_id).select(:vendor_id).first if buyer_id
        vendor_id = vendor.vendor_id if vendor
        vendor_id ||= nil
        query = query.where(vendor_id: vendor_id) if buyer_id

        if search_str && is_premium
          udprns = Trackers::Buyer.new.fetch_udprns(search_str)
          udprns = udprns.map(&:to_i)
          query = query.where(property_id: udprns)
        end

        if status == 'New'
          query = query.where(agent_id: nil)
        elsif status == 'Won'
          query = query.where(agent_id: self.id)
        elsif status == 'Lost'
          query = query.where.not(agent_id: self.id).where.not(agent_id: nil)
        end
        leads = query.order('created_at DESC').limit(PAGE_SIZE).offset(page_number*PAGE_SIZE)

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

          details = PropertyDetails.details(lead.property_id).with_indifferent_access
          details = details['_source'] ? details['_source'] : {}

          new_row = new_row.merge(['property_type', 'street_view_url', 'udprn', 'beds', 'baths', 'receptions', 'dream_price', 'pictures'].reduce({}) {|h, k| h[k] = details[k]; h })
          new_row[:address] = PropertyDetails.address(details)
          new_row[:photo_url] = details['pictures'] ? details['pictures'][0] : "Image not available"
          #new_row[:last_sale_prices] = PropertyHistoricalDetail.where(udprn: details['udprn']).order('date DESC').pluck(:price)

          #### Vendor details
          if lead.agent_id == self.id
            vendor = Vendor.where(id: lead.vendor_id).first
            new_row[:vendor_name] = vendor.name
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
            new_row[:deadline] = 168.hours.from_now.to_time.to_s
            new_row[:claimed] = false
          else
            new_row[:deadline] = lead.updated_at.to_time.to_s
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
          if status.nil?
            if lead.agent_id == self.id
              new_row[:status] = 'Won'
            elsif lead.agent_id.nil?
              new_row[:status] = 'New'
            else
              new_row[:status] = 'Lost'
            end
          else
            new_row[:status] = status
          end

          ### Verified or not
          # if new_row[:status] == 'Won'

          # end

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

      def rent_properties
        search_params = { limit: 100, fields: 'udprn' }
        search_params[:agent_id] = self.id
        search_params[:property_status_type] = 'Rent'
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
        where(new_params.slice(:provider, :uid)).first_or_initialize.tap do |user|
          user.provider = new_params['provider']
          user.uid = new_params['uid']
          user.first_name = new_params['first_name']
          user.last_name = new_params['last_name']
          user.name = new_params['first_name'] + ' ' + new_params['last_name']
          user.email = new_params['email']
          user.image_url = "http://graph.facebook.com/#{new_params['uid']}/picture?type=large"
          user.password = "12345678"
          user.oauth_token = new_params['token']
          user.oauth_expires_at = Time.at(new_params['expires_at']) rescue 24.hours.from_now
          user_details = user
        end
        user_details
      end

      ### Agents::Branches::AssignedAgent.find(23).send_vendor_email("test@prophety.co.uk", 10968961)
      def send_vendor_email(vendor_email, udprn, assigned_agent_present=true, alternate_agent_email=nil)
        hash_obj = create_hash(vendor_email, udprn)
        self.verification_hash = hash_obj.hash_value
        self.vendor_email = vendor_email
        self.email_udprn = udprn
        details = PropertyDetails.details(udprn)['_source']
        self.vendor_address = details['address']
        self.assigned_agent_present = assigned_agent_present
        self.alternate_agent_email = alternate_agent_email
        VendorMailer.welcome_email(self).deliver_now
      end

      def create_hash(vendor_email, udprn)
        salt_str = "#{vendor_email}_#{self.id}_#{self.class}"
        hash_value = BCrypt::Password.create salt_str
        hash_obj = VerificationHash.create!(email: vendor_email, hash_value: hash_value, entity_id: self.id, entity_type: self.class, udprn: udprn.to_i)
        hash_obj
      end

      def as_json option = {}
        super(:except => [:password, :password_digest])
      end
      ### TODO: Refactoring required. Figure out a better way of dumping details of a user through a consensus
      def details
        as_json(only: DETAIL_ATTRS)
      end

      def self.fetch_details(attrs=[], ids=[])
        where(id: ids).select(attrs)
      end


    end
  end
end
