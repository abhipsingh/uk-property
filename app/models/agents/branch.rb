module Agents
  class Branch < ActiveRecord::Base

    belongs_to :agent, class_name: '::Agent'
    has_many :properties, class_name: 'Agents::Branches::CrawledProperty'
    has_many :assigned_agents, class_name: '::Agents::Branches::AssignedAgent'
    attr_accessor :agent_email#, :invited_agents

    INDEPENDENT_TYPE_MAP = {
      'INDEPENDENT' => 1,
      'MAYBE' => 2,
      'ONLINE' => 3,
      'NO' => 4,
      'UNKNOWN' => 5
    }

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
      agent_ids = Agents::Branches::AssignedAgent.where(branch_id: self.id).pluck(:id)
      branch_stats = {}
      all_agent_stats = agent_ids.map do |agent_id|
        agent_api = AgentApi.new(nil, agent_id)
        agent_stats = {}
        agent_api.populate_aggregate_stats(agent_stats)
        agent_stats
      end
      
      branch_stats[:for_sale] = all_agent_stats.inject(0){|h,k| h+=k[:for_sale] }
      branch_stats[:sold] = all_agent_stats.inject(0){|h,k| h+=k[:sold] }

      keys = [:aggregate_sales, :avg_no_of_days_to_sell, :avg_achieved_more_than_valuation_count, :avg_increase_in_price, :avg_percent_of_first_valuation,
              :avg_percent_of_last_valuation]

      keys.each do |key|
        if all_agent_stats.count == 0
          branch_stats[key] = nil
        else
          branch_stats[key] = ((all_agent_stats.inject(0.0){|h,k| h+=k[key].to_f }).to_f/all_agent_stats.count).round(2)
        end
        branch_stats[key] = nil if branch_stats[key].to_i == 0
      end
      branch_stats
    end

    def vanity_url
      processed_name = name.gsub(',', ' ')
      processed_name.downcase.split(' ').join('-')
    end

#    def as_json option = {}
#      super(:except => [:verification_hash])
#    end
  end
end

