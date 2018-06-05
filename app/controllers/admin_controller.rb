class AdminController < ActionController::Base

  ### For mailshot admin dashboard
  ### curl -XGET -H "Authorization: dhiahs99asm" 'http://localhost/admin/properties/mailshot' -d '{"email" : "stephenkassi@gmail.com", "password" : "1234567890", "processed" : false, "page" :3 , "email" : "sxbzskcbs", "password" : "1234567" }'
  def mailshot_properties
    #if AdminAuth.authenticate(params[:email], params[:password])
    if true
      branch_ids = []
      query = AddressDistrictRegister
      page_size = 20
      results = []

      ### Filter query processed according to flag
      processed_flag = nil
      query = query.group(:payment_group_id)
      Rails.logger.info("QUERY_#{query.to_sql}")
      if params[:count].to_s == 'true'
        count = query.select("count(distinct(payment_group_id))").map(&:count).first
        results = { count: count }
      else
        query = query.select("payment_group_id, max(branch_id) as branch_id, max(created_at) as created_at, string_agg(udprn::text, ',') as udprns") 
        query = query.order('created_at DESC')
        query = query.limit(page_size)
        query = query.offset(((params[:page].to_i) - 1)*page_size)
        results = query.map do |mailshot_payment|
          udprns = mailshot_payment.udprns.split(',')
          cost = udprns.count.to_f * Agents::Branch::CHARGE_PER_PROPERTY_MAP['diy']
          branch_ids.push(mailshot_payment.branch_id)
          {
            payment_id: mailshot_payment.payment_group_id,
            cost: cost,
            udprns: udprns,
            payment_time: mailshot_payment.created_at,
            branch_id: mailshot_payment.branch_id
          }
  
        end
  
        ### Fetch bulk branch data
        branches_data = Agents::Branch.where(id: branch_ids).select([:name, :id, :image_url]).to_a
  
        results.each do |each_result|
          branch = branches_data.select{ |t| t.id == each_result[:branch_id] }.first
          if branch
            each_result[:branch_logo] = branch.image_url
            each_result[:branch_name] = branch.name
            each_result[:branch_id] = branch.id
          end
        end

      end

      render json: results, status: 200
    else
      render json: { message: 'Branch authentication failed' }, status: 400
    end
  end

#  ### Mark properties which has been marked for mailshot
#  ### curl -XPOST -H 'Content-Type: application/json' 'http://localhost/mark/properties/mailshot' -d '{ "payment_group_ids" : [123456, 32311], "email" : "sxbzskcbs", "password" : "1234567" }'
#  def mark_properties_mailshot
#    if AdminAuth.authenticate(params[:email], params[:password])
#    #if true
#      payment_group_ids = params[:payment_group_ids]
#      payment_group_ids = [] if !payment_group_ids.is_a?(Array)
#
#      AddressDistrictRegister.where(payment_group_id: payment_group_ids).update_all("processed = 't', expiry_date = (now()::date + interval '1 month' * months)::date ")
#      render json: { message: 'Successfully marked as processed for the payments passed' }, status: 200
#    else
#      render json: { message: 'Branch authentication failed' }, status: 400
#    end
#  end

  ### Renders a csv in the royal mail format
  ### curl -XGET 'http://localhost/udprns/royal/mail/csv' -d '{ "udprns" : [123456, 32311], "email" : "sxbzskcbs", "password" : "1234567" }'
  def udprns_royal_mail_csv
    if AdminAuth.authenticate(params[:email], params[:password])
      udprns = params[:udprns]
      properties_csv = CSV.generate(headers: true) do |csv|
        csv << PropertyService::LOCALITY_ATTRS.map(&:to_s)
        results = udprns.in_groups_of(50) do |batch|
          bulk_details = PropertyService.bulk_details(batch.compact)
          bulk_details.map do |details|
            csv << PropertyService::LOCALITY_ATTRS.map{|t| details[t] }
          end
        end
      end
      send_data properties_csv, filename: 'properties.csv'
    else
      render json: { message: 'Branch authentication failed' }, status: 400
    end
  end

end

