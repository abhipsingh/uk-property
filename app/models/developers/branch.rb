class Developers::Branch < ActiveRecord::Base
  has_many :employees, foreign_key: :employee_id
  belongs_to :company, class_name: 'Developers::Company'

  attr_accessor :developer_email, :invited_developers, :verification_hash

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
    @invited_developers ||= []
    @invited_developers.each do |invited_developer|
      self.developer_email = invited_developer['email']
      salt_str = "#{self.name}_#{self.address}_#{self.district}"
    	self.verification_hash = BCrypt::Password.create salt_str
    	VerificationHash.create(hash_value: self.verification_hash, email: self.developer_email, entity_type: 'Developers::Branches::Employee')
      DeveloperMailer.welcome_email(self).deliver_now
    end
  end
end

