module Agents
  class Branch < ActiveRecord::Base

    belongs_to :agent, class_name: '::Agent'
    has_many :properties, class_name: 'Agents::Branches::CrawledProperty'
    has_many :assigned_agents, class_name: '::Agents::Branches::AssignedAgent'
    attr_accessor :agent_email#, :invited_agents
    attr_accessor :children_vanity_urls

    #### By default, keep the scope limited to agents(not developers)
    default_scope { where(is_developer: false) }
      

    INDEPENDENT_TYPE_MAP = {
      'INDEPENDENT' => 1,
      'MAYBE' => 2,
      'ONLINE' => 3,
      'NO' => 4,
      'UNKNOWN' => 5
    }
    BRANCH_CACHE_KEY_PREFIX = 'branch_stats_'
    REVERSE_INDEPENDENT_TYPE_MAP = INDEPENDENT_TYPE_MAP.invert

    CHARGE_PER_PROPERTY_MAP = {
      'diy' => 0.2
    }

    MIN_MAILSHOT_CHARGE = 4
    MAX_BRANCH_MAILSHOT_LIMIT = 35000

    def self.table_name
      'agents_branches'
    end

    def save_verification_salt
      salt_str = "#{name}_#{address}_#{district}"
      self.verification_hash = BCrypt::Password.create salt_str
      self.save!
    end

    def verify_hash(hash_val)
      verification_hash == hash_val
    end

    def email_link
      CGI.unescape({branch_id: id, verification_hash: verification_hash, group_id: self.agent.group_id, company_id: self.agent_id }.to_query)
    end

    def send_emails(is_developer=false)
      klass = 'Developer' if is_developer
      klass ||= 'Agents::Branches::AssignedAgent'
      invited_klass = InvitedDeveloper  if is_developer
      invited_klass ||= InvitedAgent
      #@invited_agents ||= []
      first_agent_flag = (Agents::Branches::AssignedAgent.where(branch_id: self.id).count == 0)
      self.invited_agents = [ self.invited_agents.first ].compact if self.invited_agents
      self.invited_agents ||= []
      self.invited_agents.each do |invited_agent|
        invited_agent = invited_agent.with_indifferent_access
        self.agent_email = invited_agent['email']
        salt_str = "#{self.name}_#{self.address}_#{self.district}"
      	self.verification_hash = BCrypt::Password.create salt_str
        invited_klass.create!(email: self.agent_email, udprn: invited_agent['udprn'], entity_id: invited_agent['entity_id'], branch_id: self.id) if !first_agent_flag
      	VerificationHash.create(hash_value: self.verification_hash, email: self.agent_email, entity_type: klass)
        AgentMailer.welcome_email(self).deliver_now
      end
    end

    def branch_specific_stats
      cache_key = BRANCH_CACHE_KEY_PREFIX+self.id.to_s
      branch_stats = Rails.configuration.ardb_client.get(cache_key)
      if branch_stats
        branch_stats = Oj.load(branch_stats)
      else
        agent_ids = Agents::Branches::AssignedAgent.where(branch_id: self.id).pluck(:id)
        branch_stats = {}
        all_agent_stats = agent_ids.map do |agent_id|
          agent_api = AgentApi.new(nil, agent_id)
          agent_stats = {}
          agent_api.populate_aggregate_stats(agent_stats)
          agent_stats
        end

        branch_stats[:aggregate_sales] = all_agent_stats.inject(0){|h,k| h+=k[:aggregate_sales].to_i }
        branch_stats[:for_sale] = all_agent_stats.inject(0){|h,k| h+=k[:for_sale] }
        branch_stats[:sold] = all_agent_stats.inject(0){|h,k| h+=k[:sold] }
        branch_stats[:total_count] = all_agent_stats.inject(0){|h,k| h+=k[:total_count] }
        branch_stats[:green_property_count] = all_agent_stats.inject(0){|h,k| h+=k[:green_property_count] }
        branch_stats[:amber_red_property_count] = all_agent_stats.inject(0){|h,k| h+=k[:amber_red_property_count] }
        branch_stats[:aggregate_valuation] = all_agent_stats.inject(0){|h,k| h+=k[:aggregate_valuation] }

        
        Rails.configuration.ardb_client.set(cache_key, Oj.dump(branch_stats), {ex: 1.day}) ### Convert it to 1 day
      end

      branch_stats
    end

    ### Vanity url of children
    def children_vanity_urls
      branch_assigned_agents = self.assigned_agents
      branch_assigned_agents.map do |agent|
        { name: agent.name, vanity_url: agent.vanity_url }
      end
    end

    ### Vanity url of branch
    def vanity_url
      branch_vanity_url = name.downcase.gsub(/[a-z ]+/).to_a.join('').split(' ').join('-')
      company_vanity_url = self.agent.name.downcase.gsub(/[a-z ]+/).to_a.join('').split(' ').join('-')
      Rails.configuration.frontend_production_url + '/branches/details/' + [ company_vanity_url, branch_vanity_url, self.id.to_s ].join('-')
    end

#    def as_json option = {}
#      super(:except => [:verification_hash])
#    end
  end
end

