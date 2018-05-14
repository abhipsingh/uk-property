class SesService

  def self.send_bulk_emails(buyer_emails, sender, body, subject)
    # Create a new SES resource and specify a region
    if !buyer_emails.empty?
      ses = Aws::SES::Client.new(access_key_id: Rails.configuration.aws_access_key, secret_access_key: Rails.configuration.aws_access_secret, region: 'us-east-1')

      # Try to send the email.
      buyer_emails = buyer_emails + ['test@prophety.co.uk'] 
      ENV['EMAIL_ENV'] == 'dev' ? buyer_emails = ['test@prophety.co.uk'] : buyer_emails = buyer_emails
      ENV['EMAIL_ENV'] == 'dev' ? sender = 'test@prophety.co.uk' : sender = sender

      
        # Provide the contents of the email.
        resp = ses.send_email({
          destination: {
            to_addresses: buyer_emails,
          },
          message: {
            body: {
              text: {
                charset: 'UTF-8',
                data: body,
              },
            },
            subject: {
              charset: 'UTF-8',
              data: subject,
            },
          },
        source: sender,
        # Comment or remove the following line if you are not using 
        # a configuration set
        })
        puts "Email sent!"
        SesEmailRequest.create!(email: buyer_emails.join(','), template_name: nil, template_data: {}, klass: nil, request_id: resp.message_id)
      
      # If something goes wrong, display an error message.
    end
  end

end

