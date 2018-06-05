Rails.application.routes.draw do
  ### Retrieve all the unprocessed properties for mailshotting
  get 'admin/properties/mailshot',                 to: 'admin#mailshot_properties'

  ### Mark the properties as processed for mailshot
  post 'mark/properties/mailshot',                 to: 'admin#mark_properties_mailshot'

  ### Render the csv in the royal mail csv format for the udprns passed
  get 'udprns/royal/mail/csv',                     to: 'admin#udprns_royal_mail_csv'

end

