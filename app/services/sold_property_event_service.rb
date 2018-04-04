class SoldPropertyEventService

  attr_accessor :udprn, :buyer_id, :final_price, :agent_id

  def initialize(udprn: property_id, buyer_id: id, final_price: price, agent_id: agent=nil)
    @udprn = udprn
    @buyer_id = buyer_id
    @final_price = final_price
    @agent_id = agent_id if !agent_id.nil?
  end

  def close_enquiry(completion_date: date=nil)
    if completion_date
      details = PropertyDetails.details(@udprn.to_i)[:_source]
      vendor_id = details[:vendor_id]
      
      ### To accommodate for the sold property detail created earlier
      existing_sold_property = SoldProperty.where(udprn: @udprn.to_i, buyer_id: @buyer_id.to_i, agent_id: @agent_id, vendor_id: vendor_id).last
      if existing_sold_property
        existing_sold_property.completion_date = completion_date if completion_date
        existing_sold_property.save!

        ### Update the enquiry to closed won if already solf but updating the enquiry
        original_enquiries = Event.where(buyer_id: @buyer_id).where(udprn: @udprn.to_i).where(is_archived: false)
        original_enquiries.update_all(stage: Event::EVENTS[:closed_won_stage])
        enquiries = Enquiries::PropertyService.process_enquiries_result(original_enquiries)
        enquiries
      else
        ### Charge credits required from the agent if the property status is Red/Amber
        if details[:property_status_type] == 'Red' || details[:property_status_type] == 'Amber'
          offer_price = Event.where(buyer_id: @buyer_id, udprn: @udprn).last.offer_price
          credits = ((Agents::Branches::AssignedAgent::CURRENT_VALUATION_PERCENT*0.01*(offer_price.to_f)).round/Agents::Branches::AssignedAgent::PER_CREDIT_COST)
          agent = Agents::Branches::AssignedAgent.unscope(where: :is_developer).where(id: @agent_id.to_i).last

          if agent.credit >= credits
            agent.credit -= credits
            agent.save!
            
            ### Update the enquiry to closed won if property status is not green
            original_enquiries = Event.where(buyer_id: @buyer_id).where(udprn: @udprn.to_i).where(is_archived: false)

            SoldProperty.create!(udprn: @udprn.to_i, buyer_id: @buyer_id, agent_id: @agent_id, vendor_id: vendor_id, sale_price: @final_price, completion_date: completion_date)
            original_enquiries.update_all(stage: Event::EVENTS[:closed_won_stage])
            enquiries = Enquiries::PropertyService.process_enquiries_result(original_enquiries)
            enquiries
          else
            original_enquiries = Event.where(buyer_id: @buyer_id).where(udprn: @udprn.to_i).where(is_archived: false)
            enquiries =  Enquiries::PropertyService.process_enquiries_result(original_enquiries)
            enquiries
          end
        elsif details[:property_status_type] == 'Green'
          
          ### Update the enquiry to closed won if property status is Green
          original_enquiries = Event.where(buyer_id: @buyer_id).where(udprn: @udprn.to_i).where(is_archived: false)
          original_enquiries.update_all(stage: Event::EVENTS[:closed_won_stage])
          SoldProperty.create!(udprn: @udprn.to_i, buyer_id: @buyer_id, agent_id: @agent_id, vendor_id: vendor_id, sale_price: @final_price, completion_date: completion_date)
          enquiries = Enquiries::PropertyService.process_enquiries_result(original_enquiries)
          enquiries
        end

      end

    else
      []
    end
  end

end

