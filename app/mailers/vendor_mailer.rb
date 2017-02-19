class VendorMailer < ApplicationMailer
  def welcome_email(user)
    @user = user
    mail(to: @user.vendor_email, subject: "Welcome to Prophety #{@user.vendor_email}")
  end

  def signup_email(hash)
    @email = hash[:email]
    @hash = @hash
    @link = hash[:link]
    mail(to: @email, subject: "Vendor Registration #{@email}")
  end
end