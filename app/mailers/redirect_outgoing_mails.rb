class RedirectOutgoingMails
  class << self
 
    def delivering_email(mail)
      mail.to = 'test@prophety.co.uk'
    end
 
  end
end

