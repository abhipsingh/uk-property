class SesService

  def self.send_bulk_emails(buyer_emails, sender, body, subject)
    # Create a new SES resource and specify a region
    if !buyer_emails.empty?
      ses = Aws::SES::Client.new(access_key_id: Rails.configuration.aws_access_key, secret_access_key: Rails.configuration.aws_access_secret, region: 'us-east-1')
      
      # Try to send the email.
      buyer_emails = buyer_emails + ['test@prophety.co.uk'] 
      begin
      
        # Provide the contents of the email.
        resp = ses.send_email({
          destination: {
            to_addresses: buyer_emails,
          },
          message: {
            body: {
              text: {
                charset: encoding,
                data: body,
              },
            },
            subject: {
              charset: encoding,
              data: subject,
            },
          },
        source: sender,
        # Comment or remove the following line if you are not using 
        # a configuration set
        })
        puts "Email sent!"
      
      # If something goes wrong, display an error message.
      rescue Aws::SES::Errors::ServiceError => error
        Rails.logger.info("SES_EMAIL_ERROR_Email not sent. Error message: #{error}")
      end
    end
  end

end

