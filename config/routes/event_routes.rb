Rails.application.routes.draw do
  namespace :events do

    ### Book the calendar to the agents and buyers about the property's viewing
    post 'property/book/viewing/:udprn',                 action: :book_calendar

    ### Shows the calendar to the agents and buyers about the property's viewing
    get '/property/viewing/availability/:udprn',         action: :show_calendar 

    ### Details of a viewing
    get 'viewing/details/:id',                           action: :show_calendar_booking_details

    ### Edit viewing 
    post 'viewing/edit/:id',                             action: :edit_calendar_viewing

    ### Delete viewing
    post 'viewing/delete/:id',                           action: :delete_calendar_viewing

    ### Get viewings of a buyer
    get 'viewings/buyer',                                action: :buyer_calendar_events

    ### Delete viewing using an enquiry id
    post 'viewing/delete/enquiry/:enquiry_id',           action: :delete_calendar_viewing_by_enquiry

    ### Edit viewing using an enquiry id
    post 'events/viewing/enquiry/edit/:enquiry_id',      action: :edit_calendar_viewing_by_enquiry

  end
end

