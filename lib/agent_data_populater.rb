class AgentDataPopulater

  def self.extract_groups
    group_names = []
    non_address_branches = File.open('incomplete_branch_addresses.csv', 'a')
    company_count = 0
    group_count = 0
    begin
    CSV.foreach("/mnt3/final_agent_branch_data.csv", :row_sep => :auto, :col_sep => ",") do |row|
      branch_address = row[9]
      if branch_address
        branch_address = branch_address.gsub(","," ").strip
        if branch_address
          if branch_address.split(" ").length > 2

            postcode = branch_address.split(" ")[-2..-1].join(" ")
            district = postcode.split(' ')[0]
            zoopla_branch_id = row[7]
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
            branch_phone_number == '0' ? branch_phone_number = nil : branch_phone_number = 0
            suitable_for_launch  == 'YES' ? suitable_for_launch = true : suitable_for_launch = false
            zoopla_company_id = row[1]
            group_name = row[4]
            company_website = row[16]
            independent = row[3]
            company_id = nil
            group_id = nil
            group_name ||= company_name

            independent_type = Agents::Branch::INDEPENDENT_TYPE_MAP[independent]
            if independent_type.nil?
              type = independent.split('/')[0]
              independent_type = Agents::Branch::INDEPENDENT_TYPE_MAP[type]
            end

            if independent_type.nil?
              type = independent.split(' ')[0]
              independent_type = Agents::Branch::INDEPENDENT_TYPE_MAP[type]
            end

            group = Agents::Group.where(name: group_name).last
            group_created = false
            company_created = false
            if !group || group.id < 7885
              group = Agents::Group.create!(name: group_name)
              group_created = true
              group_count += 1
              group_created = true
            end
            group_id = group.id

            company = Agent.where(name: company_name).last
            if !company || company.id < 7886
              company = Agent.create!(name: company_name, zoopla_company_id: zoopla_company_id, independent: independent_type, group_id: group_id)
              company_count += 1
              company_created = true
            end
            company_id = company.id

            Agents::Branch.create!(
              district: district,
              name: processed_branch_name,
              zoopla_branch_id: zoopla_branch_id,
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


          end

        end
      end
    end
    ensure
      p "Group count #{group_count} and Company count #{company_count}"
      non_address_branches.close
    end
    group_names.group_by{|t| t }.count
  end

end

