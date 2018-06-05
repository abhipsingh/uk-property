class AdminAuth

  def self.authenticate(email, password)
    true
    #(email == ENV['ADMIN_EMAIL']) && (ENV['ADMIN_AUTH'] == password)
  end

end

