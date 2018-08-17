Rails.application.routes.draw do
  namespace :events do

    ### Book the calendar to the agents and buyers about the property's viewing
    post 'property/book/viewing/:udprn',                 to: :book_calendar

    ### Shows the calendar to the agents and buyers about the property's viewing
    get '/property/viewing/availability/:udprn',         to: :show_calendar 
  end
end
