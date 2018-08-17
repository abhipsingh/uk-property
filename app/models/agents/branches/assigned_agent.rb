module Agents
  module Branches
    class AssignedAgent < ActiveRecord::Base
      has_secure_password

      has_many :quotes, class_name: 'Agents::Branches::AssignedAgents::Quote', foreign_key: 'agent_id'
      has_many :leads, class_name: 'Agents::Branches::AssignedAgents::Lead', foreign_key: 'agent_id'

      belongs_to :branch, class_name: 'Agents::Branch'
      attr_accessor :vendor_email, :vendor_address, :email_udprn, :verification_hash, :assigned_agent_present, :alternate_agent_email, :source

      ### TODO: Refactoring required. Figure out a better way of dumping details of a user through a consensus
      DETAIL_ATTRS = [:id, :name, :email, :mobile, :branch_id, :title, :office_phone_number, :mobile_phone_number, :image_url, :invited_agents, :provider, :uid, :is_premium]

      PER_CREDIT_COST = 1
      QUOTE_CREDIT_LIMIT = -10
      LEAD_CREDIT_LIMIT = 10
      PER_LEAD_COST = 10
      PAGE_SIZE = 10
      PREMIUM_COST = 25
      MIN_INVITED_FRIENDS_FAMILY_VALUE = 1

      ONE_TIME_UNLOCKING_COST = 100

      PER_BUYER_ENQUIRY_EMAIL_COST = 0.05

      trigger.before(:update).of(:email) do
        "NEW.email = LOWER(NEW.email); RETURN NEW;"
      end
    
      trigger.before(:insert) do
        "NEW.email = LOWER(NEW.email); RETURN NEW;"
      end
    
      ### Percent of current valuation charged as commission for quotes submission
      CURRENT_VALUATION_PERCENT = 0.01

      #### By default, keep the scope limited to agents(not developers)
      default_scope { where(is_developer: false) }
      
      def calculate_is_first_agent
        email = self.email
        branch_id = self.branch_id
        first_agent = self.class.unscope(where: :is_developer).where(branch_id: branch_id).select(:email).order('created_at ASC').limit(1).first
        flag = (first_agent.email == email) if first_agent
        flag = true if first_agent.nil?
        flag ||= false
        flag
      end

      def name
        str = self.first_name rescue nil
        str += ' ' if str
        str += self.last_name if str
        str ||= self.last_name
      end
 
      ##### All recent quotes for the agent being displayed
      ##### Data being fetched from this function
      ##### Example run the following in irb
      ##### Agents::Branches::AssignedAgent.last.recent_properties_for_quotes
      def recent_properties_for_quotes(payment_terms_params=nil, service_required_param=nil, status_param=nil, search_str=nil, property_for='Sale', buyer_id=nil, is_premium=false, page_number=1, count=false, latest_time=nil)
        results = []
        count = nil

        won_status = Agents::Branches::AssignedAgents::Quote::STATUS_HASH['Won']
        lost_status = Agents::Branches::AssignedAgents::Quote::STATUS_HASH['Lost']
        vendor = PropertyBuyer.where(id: buyer_id).select(:vendor_id).first if buyer_id
        vendor_id = vendor.vendor_id if vendor
        vendor_id ||= nil
        # udprns = quotes.where(district: self.branch.district).order('created_at DESC').pluck(:property_id)
        services_required = Agents::Branches::AssignedAgents::Quote::REVERSE_SERVICES_REQUIRED_HASH[service_required_param]
        new_status = Agents::Branches::AssignedAgents::Quote::STATUS_HASH['New']
        query = Agents::Branches::AssignedAgents::Quote
        klass = Agents::Branches::AssignedAgents::Quote

        ### District of that branch
        branch = self.branch
        query = klass.where("(district = ? OR (existing_agent_id = ?))", branch.district, self.id)
        query = query.where('created_at > ?', Time.parse(latest_time)) if latest_time
        max_hours_for_expiry = Agents::Branches::AssignedAgents::Quote::MAX_VENDOR_QUOTE_WAIT_TIME

        ### 48 hour expiry deadline
        #query = query.where("(agent_id = ? AND status = ?) OR (agent_id is null and status = ? AND created_at > ?)", self.id, won_status, new_status, max_hours_for_expiry.ago)
        query = query.where(vendor_id: vendor_id) if buyer_id
        query = query.where(payment_terms: payment_terms_params) if payment_terms_params
        query = query.where(services_required: services_required) if service_required_param
        query = query.where("((agent_id is null and status = ? and expired = 'f') OR ( agent_id = ? and ( expired= 't' OR status = ? OR status = ? ))) OR pre_agent_id = ? ", new_status, self.id, won_status, lost_status, self.id)
        
 

        if status_param == 'New'
          query = query.where(agent_id: nil).where(expired: false)
        elsif status_param == 'Lost'
          query = query.where(agent_id: self.id).where(status: lost_status)
        elsif status_param == 'Pending'
          query = query.where(agent_id: self.id).where(status: new_status).where(expired: false)
        elsif status_param == 'Won'
          query = query.where(agent_id: self.id).where(status: won_status)
        elsif status_param == 'Expired'
          query = query.where(expired: true)
        end

        final_results = []
        results = []

        if self.is_premium
          count = query.count
          results = query.order('created_at DESC')
        else
          #Rails.logger.info(query.to_sql)
          count = query.count
          page_number ||= 1
          page_number = page_number.to_i
          page_number -= 1
          results = query.order('created_at DESC').limit(PAGE_SIZE).offset(page_number*PAGE_SIZE)
        end

        property_ids = results.map(&:property_id)
        winning_quotes = klass.where(status: won_status).where(property_id: property_ids).select([:agent_id, :property_id])
        agents_property_hash = winning_quotes.reduce({}) { |acc_hash, hash| acc_hash.merge(hash.property_id => hash)}
        agent_ids = winning_quotes.map(&:agent_id).uniq
        agents_results = self.class.joins(:branch).where(id: agent_ids).select(['agents_branches_assigned_agents.id', 'agents_branches_assigned_agents.first_name', 'agents_branches.image_url', 'agents_branches_assigned_agents.last_name'])
        agent_result_hash = agents_results.reduce({}) { |acc_hash, hash| acc_hash.merge(hash.id => hash)}

        results.each do |each_quote|
          new_row = {}
          property_details = PropertyDetails.details(each_quote.property_id)['_source']
          ### Quotes status filter
          property_id = property_details['udprn'].to_i
          agent_quote = nil
          quote_status = nil
          if each_quote.status == won_status
            quote_status = 'Won'
            new_row[:locked_status] = false
          elsif each_quote.status == new_status && each_quote.agent_id.nil? && each_quote.expired == false
            agent_quote = Agents::Branches::AssignedAgents::Quote.where(agent_id: self.id).where(property_id: each_quote.property_id).where(expired: false).where(status: new_status).last

            if !agent_quote.nil?
              quote_status = 'Pending'
              new_row[:locked_status] = true
            else
              quote_status = 'New'
              new_row[:locked_status] = false
            end

          elsif each_quote.expired
            quote_status = 'Expired'
            new_row[:locked_status] = false
          else
            quote_status = 'Lost'
            new_row[:locked_status] = false
          end
          new_row[:id] = each_quote.id
          new_row[:credits_required] = ((each_quote.amount.to_f)*(0.01*0.01)).round/PER_CREDIT_COST
          new_row[:udprn] = property_id
          new_row[:terms_url] = agent_quote.terms_url if agent_quote
          new_row[:terms_url] ||= each_quote.terms_url
          new_row[:created_at] = each_quote.created_at
          new_row[:submitted_on] = agent_quote.created_at.to_s if agent_quote
          new_row[:submitted_on] ||= each_quote.created_at.to_s
          new_row[:quote_submitted] = !agent_quote.nil?

          new_row[:status] = klass::REVERSE_STATUS_HASH[each_quote.status]
          
          new_row[:status] = quote_status if quote_status == 'Expired'

          new_row[:property_status_type] = property_details['property_status_type']
          #new_row[:activated_on] = property_details['status_last_updated']
          new_row[:activated_on] = each_quote.created_at.to_s
          new_row[:type] = 'SALE'
          new_row[:photo_url] = property_details['pictures'] ? property_details['pictures'][0] : "Image not available"
          new_row[:vanity_url]= property_details[:vanity_url]

          new_row[:percent_completed] = property_details['percent_completed']
          new_row[:percent_completed] ||= PropertyService.new(property_details['udprn']).compute_percent_completed({}, property_details)

          new_row = new_row.merge(['property_type', 'beds', 'baths', 'receptions', 'floor_plan_url',
            'verification_status','asking_price','fixed_price', 'dream_price', 'pictures', 'quotes', 'claimed_on', 'address'].reduce({}) {|h, k| h[k] = property_details[k]; h })
          new_row['payment_terms'] = nil
          new_row['payment_terms'] = agent_quote.payment_terms  if agent_quote
          new_row['payment_terms'] ||= each_quote.payment_terms
          new_row['services_required'] = Agents::Branches::AssignedAgents::Quote::SERVICES_REQUIRED_HASH[each_quote.service_required.to_s.to_sym]

          new_row[:quote_details] = agent_quote.quote_details if agent_quote
          new_row[:quote_details] ||= each_quote.quote_details
          

          new_row[:assigned_agent_id] = property_details[:agent_id]
          new_row[:assigned_agent_name] = property_details[:assigned_agent_first_name].to_s + ' ' + property_details[:assigned_agent_last_name].to_s
          new_row[:assigned_branch_logo] = property_details[:assigned_agent_branch_logo]
          new_row[:assigned_branch_name] = property_details[:assigned_agent_branch_name]

          new_row['street_view_url'] = "https://#{ENV['S3_STREET_VIEW_BUCKET']}.s3.#{ENV['S3_REGION']}.amazonaws.com/#{property_details[:udprn]}.jpg"
          new_row[:current_valuation] = property_details['current_valuation']
          new_row[:latest_valuation] = property_details['current_valuation']

          ### Historical prices
          new_row[:historical_prices] = property_details['sale_prices']

          if (quote_status == 'Won') || property_details[:agent_id].to_i == self.id
            new_row[:vendor_id] = property_details['vendor_id']
            new_row[:vendor_first_name] = property_details['vendor_first_name']
            new_row[:vendor_last_name] = property_details['vendor_last_name']
            new_row[:vendor_email] = property_details['vendor_email']
            new_row[:vendor_mobile] = property_details['vendor_mobile_number']
            new_row[:vendor_image_url] = property_details['vendor_image_url']
          else
            new_row[:vendor_id] = nil
            new_row[:vendor_first_name] = nil
            new_row[:vendor_last_name] = nil
            new_row[:vendor_email] = nil
            new_row[:vendor_mobile] = nil
            new_row[:vendor_image_url] = nil
            new_row['address'] = PropertyDetails.street_address(property_details)
          end

          ### TODO: Fix for multiple lifetimes
          new_row[:quotes_received] = Agents::Branches::AssignedAgents::Quote.where(property_id: property_id).where.not(agent_id: nil).where(expired: false).count

          ### TODO: Fix for multiple lifetimes
          #### WINNING AGENT
          if quote_status == 'Won' || quote_status == 'Lost'
            winning_agent = agent_result_hash[agents_property_hash[each_quote.property_id].agent_id] rescue nil
            if winning_agent
              new_row[:winning_agent_name] = winning_agent.first_name.to_s + ' ' + winning_agent.last_name.to_s
              new_row[:winning_agent_branch_logo] = winning_agent.image_url
            end
          end
          new_row[:claimed_on] = each_quote.created_at
          new_row[:deadline] = (each_quote.created_at + Agents::Branches::AssignedAgents::Quote::MAX_AGENT_QUOTE_WAIT_TIME).to_s
          new_row[:vendor_deadline_end] = (each_quote.created_at + Agents::Branches::AssignedAgents::Quote::MAX_VENDOR_QUOTE_WAIT_TIME).to_s
          new_row[:vendor_deadline_start] = (each_quote.created_at + Agents::Branches::AssignedAgents::Quote::MAX_AGENT_QUOTE_WAIT_TIME).to_s
          new_row[:claimed_on] = Time.parse(new_row['claimed_on']).strftime("%Y-%m-%dT%H:%M:%SZ") if new_row['claimed_on']
          new_row[:submitted_on] = Time.parse(new_row[:submitted_on]).strftime("%Y-%m-%dT%H:%M:%SZ") if new_row[:submitted_on]
          new_row[:deadline] = Time.parse(new_row[:deadline]).strftime("%Y-%m-%dT%H:%M:%SZ") if new_row[:deadline]
          new_row[:activated_on] = Time.parse(new_row[:activated_on]).strftime("%Y-%m-%dT%H:%M:%SZ") if new_row[:activated_on]

          final_results.push(new_row)

        end

        return final_results, count
      end


      ##### All leads for agents will be fetched using this method
      #### To try this in console
      #### Agents::Branches::AssignedAgent.last.recent_properties_for_claim
      #### New properties udprns for testing
      #### 4745413, 4745410, 4745409, 4745408, 4745399
      #### To test this function, create the following lead.
      #### Agents::Branches::AssignedAgents::Lead.create(district: "CH45", property_id: 4745413, vendor_id: 1)
      #### Then call the following function for the agent in that district
      def recent_properties_for_claim(status=nil, property_for='Sale', buyer_id=nil, search_str=nil, is_premium=false, page_number=1, owned_property=nil, count=false, latest_time=nil)
        ### District of that branch
        branch = self.branch
        district = branch.district
        query = Agents::Branches::AssignedAgents::Lead
        vendor = PropertyBuyer.where(id: buyer_id).select(:vendor_id).first if buyer_id
        vendor_id = vendor.vendor_id if vendor
        vendor_id ||= nil
        source_mailshot = Agents::Branches::AssignedAgents::Lead::SOURCE_MAP[:mailshot]
        branch_id = self.branch_id

        if !self.locked
          query = query.where('created_at > ?', Time.parse(latest_time)) if latest_time
          query = query.where(vendor_id: vendor_id) if buyer_id
          query = query.where(owned_property: owned_property) if !owned_property.nil?
          query = query.where("(((district = ? AND owned_property = 'f') OR (owned_property='t' AND agent_id = ?))  AND source is null ) OR ( source = ? AND pre_agent_id = ? )", district, self.id, source_mailshot, self.id)
  
          if search_str && is_premium
            udprns = Enquiries::PropertyService.fetch_udprns(search_str)
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

          Rails.logger.info("QUERY_#{query.to_sql}")

          if self.is_premium
            leads = query.order('created_at DESC')
            results = leads.map{|lead| populate_lead_details(lead, status) }
            return results, results.count
          else
            count = query.count
            page_number ||= 1
            page_number = page_number.to_i
            page_number -= 1
            leads = query.order('created_at DESC').limit(PAGE_SIZE).offset(page_number.to_i*PAGE_SIZE)
            results = leads.map{|lead| populate_lead_details(lead, status) }
            return results, count
          end
        else
          return [], 0
        end

      end

      def personal_claimed_properties
        leads = Agents::Branches::AssignedAgents::Lead.where(agent_id: self.id).where(vendor_id: nil).where(owned_property: true)
        leads.map { |lead| populate_lead_details(lead, nil) }
      end

      def populate_lead_details(lead, status)
        new_row = {}
        new_row[:id] = lead.id
        #### Submitted on
        if lead.agent_id && lead.agent_id != self.id
          new_row[:submitted_on] = (lead.created_at + (1..5).to_a.sample.seconds).to_s
        elsif lead.agent_id
          new_row[:submitted_on] = lead.claimed_at.to_s if lead.claimed_at
        else
          new_row[:submitted_on] = nil
        end
        new_row[:created_at] = lead.created_at

        ### Tag a lead with preemption
        new_row[:preempted_property] = !lead.pre_agent_id.nil?

        details = PropertyDetails.details(lead.property_id)[:_source]
        new_row = new_row.merge(['property_type', 'street_view_url', 'udprn', 'beds', 'baths', 'receptions', 'dream_price', 'pictures', 'street_view_image_url', 'claimed_on', 'address', 'sale_prices', 'vanity_url', 'property_status_type'].reduce({}) {|h, k| h[k] = details[k]; h })
        new_row['street_view_url'] = "https://#{ENV['S3_STREET_VIEW_BUCKET']}.s3.#{ENV['S3_REGION']}.amazonaws.com/#{details[:udprn]}.jpg"
        new_row[:photo_url] = details['pictures'] ? details['pictures'][0] : "Image not available"
        #new_row[:last_sale_prices] = PropertyHistoricalDetail.where(udprn: details['udprn']).order('date DESC').pluck(:price)
        
        ### Total cost of lead
        new_row[:credits_required] = PER_LEAD_COST

        new_row[:last_sale_price] = new_row['sale_prices'].last['price'] rescue nil

        #### Vendor details
        if lead.agent_id == self.id
          new_row[:vendor_id] = details[:vendor_id]
          new_row[:vendor_first_name] = details[:vendor_first_name]
          new_row[:vendor_last_name] = details[:vendor_last_name]
          new_row[:vendor_email] = details[:vendor_email]
          new_row[:vendor_mobile] = details[:vendor_mobile_number]
          new_row[:vendor_image_url] = details[:vendor_image_url]
        else
          new_row[:vendor_id] = nil
          new_row[:vendor_first_name] = nil 
          new_row[:vendor_last_name] = nil
          new_row[:vendor_email] = nil
          new_row[:vendor_mobile] = nil
          new_row[:vendor_image_url] = nil
        end

        ### Indicates that a property is claimed through friends and family or not
        new_row[:fnf_property] = lead.owned_property

        ### Update percent completed
        new_row[:percent_completed] = details['percent_completed']
        new_row[:percent_completed] ||= PropertyService.new(details[:udprn]).compute_percent_completed({}, details)

        ### Deadline
        new_row[:deadline] = (lead.claimed_at.to_time +  Agents::Branches::AssignedAgents::Lead::VERIFICATION_DAY_LIMIT).to_s if lead.claimed_at
        if lead.agent_id.nil?
          new_row[:claimed] = false
        else
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
            new_row['address'] = PropertyDetails.street_address(details)
          else
            new_row[:status] = 'Lost'
            new_row['address'] = PropertyDetails.street_address(details)
          end
        else
          new_row[:status] = status
        end

        ### Visit time if any
        new_row[:visit_time] = Time.parse(lead.visit_time.to_s).strftime("%Y-%m-%dT%H:%M:%SZ") if lead.visit_time

        ### Normalize timestamps
        new_row[:claimed_on] = lead.claimed_at
        new_row[:claimed_on] ||= Time.parse(new_row[:claimed_on].to_s).strftime("%Y-%m-%dT%H:%M:%SZ") if new_row[:claimed_on]
        new_row[:claimed_on] ||= Time.parse(lead.created_at.to_s).strftime("%Y-%m-%dT%H:%M:%SZ")
        new_row[:owned_property] = lead.owned_property
        new_row[:submitted_on] = Time.parse(new_row[:submitted_on]).strftime("%Y-%m-%dT%H:%M:%SZ") if new_row[:submitted_on]
        new_row[:deadline] = Time.parse(new_row[:deadline]).strftime("%Y-%m-%dT%H:%M:%SZ") if new_row[:deadline]
        new_row
      end

      def active_properties
        search_params = { limit: 100 }
        search_params[:agent_id] = self.id
        search_params[:property_status_type] = 'Green'
        search_params[:verification_status] = true
        api = PropertySearchApi.new(filtered_params: search_params)
        api.apply_filters
        api.query.delete(:from)
        api.query.delete(:to)
        api.query[:size] = 1000
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
        where(new_params.slice(:email)).first_or_initialize.tap do |user|
          user.provider = new_params['provider']
          user.uid = new_params['uid']
          user.first_name = new_params['first_name']
          user.last_name = new_params['last_name']
          user.name = new_params['first_name'] + ' ' + new_params['last_name']
          user.email = new_params['email']
          if new_params['provider'] == 'linkedin'
            user.image_url = new_params['image_url']
          else
            user.image_url = "http://graph.facebook.com/#{new_params['uid']}/picture?type=large"
          end
          user.password = "#{ENV['OAUTH_PASSWORD']}"
          user.oauth_token = new_params['token']
          user.oauth_expires_at = Time.at(new_params['expires_at']) rescue  Agents::Branches::AssignedAgents::Quote::MAX_VENDOR_QUOTE_WAIT_TIME.from_now
          user_details = user
        end
        user_details
      end

      ### Agents::Branches::AssignedAgent.find(23).send_vendor_email("test@prophety.co.uk", 10968961)
      def send_vendor_email(vendor_email, udprn, assigned_agent_present=true, alternate_agent_email=nil)
        if (Vendor.where(email: vendor_email).count == 0)
          hash_obj = create_hash(vendor_email, udprn)
          self.verification_hash = hash_obj.hash_value
          self.vendor_email = vendor_email
          self.email_udprn = udprn
          details = PropertyDetails.details(udprn)['_source']
          self.vendor_address = details['address']
          self.assigned_agent_present = assigned_agent_present
          self.alternate_agent_email = alternate_agent_email
          self.source = 'properties'
          VendorMailer.welcome_email(self).deliver_now
        end
        ### http://prophety-test.herokuapp.com/auth?verification_hash=<%=@user.verification_hash%>&udprn=<%=@user.email_udprn%>&email=<%=@user.vendor_email%>
      end

      def create_hash(vendor_email, udprn)
        salt_str = "#{vendor_email}_#{self.id}_#{self.class}"
        hash_value = BCrypt::Password.create salt_str
        hash_obj = VerificationHash.create!(email: vendor_email, hash_value: hash_value, entity_id: self.id, entity_type: 'Vendor', udprn: udprn.to_i)
        hash_obj
      end

      def as_json option = {}
        super(:except => [:password, :password_digest])
      end
 
      ### Vanity url of agent
      def vanity_url
        branch_name = self.branch.name.downcase.gsub(/[a-z ]+/).to_a.join('').split(' ').join('-')
        company_name = self.branch.agent.name.downcase.gsub(/[a-z ]+/).to_a.join('').split(' ').join('-')
        agent_name = name
        agent_name ||= ''
        agent_name = agent_name.downcase.gsub(/[a-z ]+/).to_a.join('').split(' ').join('-')
        Rails.configuration.frontend_production_url + '/agents/' + [ company_name, branch_name, agent_name, self.id.to_s ].join('-')
      end

      ### TODO: Refactoring required. Figure out a better way of dumping
      ### details of a user through a consensus
      def details
        hash = as_json(only: DETAIL_ATTRS)
        hash['vanity_url'] = vanity_url
        hash
      end

      def self.fetch_details(attrs=[], ids=[])
        where(id: ids).select(attrs)
      end


    end
  end
end
