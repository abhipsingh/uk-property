class AgentDataPopulater

  def self.extract_groups
    group_names = []
    non_address_branches = File.open('incomplete_branch_addresses.csv', 'a')
    company_count = 0
    group_count = 0
    line = 0
    begin
    CSV.foreach("/mnt3/master_data.csv", :row_sep => :auto, :col_sep => ",") do |row|
      branch_address = row[9]
      if branch_address
        branch_address = branch_address.gsub(","," ").strip
        if branch_address
          if branch_address.split(" ").length > 2

            postcode = branch_address.split(" ")[-2..-1].join(" ")
            district = postcode.split(' ')[0]
            zoopla_branch_id = row[7]
            is_ready_for_launch = nil
            row[5] == 'YES' ? is_ready_for_launch = true : is_ready_for_launch = false
            prophety_branch_id = row[6].to_i
            prophety_company_id = row[0].to_i
            zoopla_company_id = row[1].to_i
            branch_name = row[8]
            branch_address = row[9]
            branch_phone_number = row[15]
            branch_email = row[11]
            branch_sales_email = row[12]
            branch_lettings_email = row[13]
            branch_commercial_email = row[14]
            branch_website = row[16]
            suitable_for_launch = row[5]
            company_name = row[2]
            processed_branch_name = [ company_name, branch_name ].compact.join(', ')
            branch_phone_number == '0' ? branch_phone_number = nil : branch_phone_number = branch_phone_number
            suitable_for_launch  == 'YES' ? suitable_for_launch = true : suitable_for_launch = false
            zoopla_company_id = row[1]
            group_name = row[4]
            company_website = row[16]
            independent = row[3]
            company_id = nil
            group_id = nil
            group_name ||= company_name
            
            if prophety_company_id.to_i == 4845
            emails = [ branch_email, branch_lettings_email, branch_sales_email, branch_commercial_email ]
            domain_name_length = emails.map{ |t| t.strip if t}.map{ |t| t.split('@').last  if t }.compact.uniq.length
            company_count += 1 if domain_name_length > 1
            domain_name = emails.map{ |t| t.strip  if t}.map{ |t| t.split('@').last  if t }.compact.uniq if domain_name_length == 1
            p emails if domain_name_length > 1
            
            independent_type = Agents::Branch::INDEPENDENT_TYPE_MAP[independent]
            if independent_type.nil?
              type = independent.split('/')[0]
              independent_type = Agents::Branch::INDEPENDENT_TYPE_MAP[type]
            end

            if independent_type.nil?
              type = independent.split(' ')[0]
              independent_type = Agents::Branch::INDEPENDENT_TYPE_MAP[type]
            end

            company = Agent.where(prophety_company_id: prophety_company_id).last
            p company.id if domain_name_length > 1
            if !company
              group = Agents::Group.create!(name: group_name)
              group_count += 1
              group_id = group.id
              company = Agent.create!(name: company_name, zoopla_company_id: zoopla_company_id, independent: independent_type, group_id: group_id, is_ready_for_launch: is_ready_for_launch, prophety_company_id: prophety_company_id)
              company_count += 1
            end
            company_id = company.id

            branch = Agents::Branch.create!(
              district: district,
              name: processed_branch_name,
              zoopla_branch_id: zoopla_branch_id,
              prophety_branch_id: prophety_branch_id,
              address: branch_address,
              phone_number: branch_phone_number,
              email: branch_email,
              sales_email: branch_sales_email,
              lettings_email: branch_lettings_email,
              commercial_email: branch_commercial_email,
              website: branch_website,
              suitable_for_launch: suitable_for_launch,
              agent_id: company_id
            )
            #Agents::Branch.where(agent_id: company_id, district: district, name: processed_branch_name, zoopla_branch_id: zoopla_branch_id).update_all(domain_name: domain_name.last) if domain_name
            line += 1
            end
            
          end

        end
      end
    end
    ensure
      p "Line no. #{line} "
      p "Group count #{group_count} and Company count #{company_count}"
      non_address_branches.close
    end
    group_names.group_by{|t| t }.count
  end

end

