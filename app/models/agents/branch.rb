module Agents
  class Branch < ActiveRecord::Base
    belongs_to :agent, class_name: '::Agent'
    has_many :properties, class_name: 'Agents::Branches::CrawledProperty'

    has_many :assigned_agents, class_name: '::Agents::Branches::AssignedAgent'

    attr_accessor :agent_email

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

    def send_emails
      invited_agents.each do |invited_agent|
        self.agent_email = invited_agent['email']
        salt_str = "#{self.name}_#{self.address}_#{self.district}"
      	self.verification_hash = BCrypt::Password.create salt_str
      	VerificationHash.create(hash_value: self.verification_hash, email: self.email, entity_type: 'Agents::Branches::AssignedAgent')
        AgentMailer.welcome_email(self).deliver_now
      end
    end

#    def as_json option = {}
#      super(:except => [:verification_hash])
#    end
  end
end

