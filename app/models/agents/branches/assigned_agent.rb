module Agents
  module Branches
    class AssignedAgent < ActiveRecord::Base

      has_many :quotes, class_name: 'Agents::Branches::AssignedAgents::Quote', foreign_key: 'agent_id'

      belongs_to :branch

      ##### All recent quotes for the agent being displayed
      ##### Data being fetched from this function
      ##### Example run the following in irb
      ##### Agents::Branches::AssignedAgent.last.recent_properties_for_quotes
      def recent_properties_for_quotes
        results = []
        search_params = {
          district: self.branch.district,
          sort_order: 'desc',
          sort_key: 'status_last_updated',
          udprn: '10966139'  ### TODO To be changed, Used for testing
        }
        api = PropertyDetailsRepo.new(filtered_params: search_params)
        api.apply_filters
        body, status = api.fetch_data_from_es
        if status.to_i == 200
          body.each do |property_details|
            new_row = {}
            property_id = property_details['udprn'].to_i
            quotes = self.quotes.where(property_id: property_id).where('created_at > ?', 1.week.ago)
            if quotes.count > 0
              new_row[:submittted_on] = quotes.first.created_at.to_s
              new_row[:status] = quotes.first.status
              new_row[:status] ||= 'PENDING'
            else
              new_row[:submittted_on] = nil
              new_row[:status] = 'PENDING'
            end
            new_row[:activated_on] = property_details['status_last_updated']
            new_row[:type] = 'SALE'
            new_row[:property_url] = property_details['photos'][0]
            new_row[:address] = PropertyDetails.address(property_details)

            ### Price details starts
            if property_details['status'] == 'Green'
              keys = ['asking_price', 'offers_price', 'fixed_price']
              
              keys.select{ |t| property_details.has_key?(t) }.each do |present_key|
                new_row[present_key] = property_details[present_key]
              end
                
            else
              new_row[:latest_valuation] = property_details['current_valuation'][0]
            end
            ### Price details ends
            if quotes.first.status == Agents::Branches::AssignedAgents::Quote::STATUS_HASH['Won']
              vendor = Vendor.where(property_id: property_id).where(status: Vendor::STATUS_HASH['Verified']).first
              new_row[:vendor_name] = vendor.full_name
              new_row[:email] = vendor.email
              new_row[:mobile] = vendor.mobile
            else
              new_row[:vendor_name] = nil
              new_row[:email] = nil
              new_row[:mobile] = nil
            end

            new_row[:property_type] = property_details['property_type']
            new_row[:beds] = property_details['beds']
            new_row[:baths] = property_details['baths']
            new_row[:receptions] = property_details['receptions']
            new_row[:floor_plan_url] = property_details['floor_plan_url']
            new_row[:current_agent] = property_details['assigned_agent_branch_name']
            new_row[:service_required] = property_details['service_required']

            ### TODO new_row[:payment_terms] =

            new_row[:quotes_received] = Agents::Branches::AssignedAgents::Quote.where(property_id: property_id).where('created_at > ?', 1.week.ago).count
            new_row[:deadline] = Time.at(Time.parse(property_details['status_last_updated']) + 48.hours - Time.now).utc.strftime "%H:%M:%S"

            #### WINNING AGENT
            winning_quote = Agents::Branches::AssignedAgents::Quote.where(status: Agents::Branches::AssignedAgents::Quote::REVERSE_STATUS_HASH['Won'], property_id: property_id).first
            if winning_quote
              new_row[:winning_agent] = winning_quote.agent.name
              new_row[:quote_price] = winning_quote.compute_price
            else
              new_row[:winning_quote] = nil
              new_row[:quote_price] = nil
            end

            results.push(new_row)

          end
        end
        results
      end


    end
  end
end
