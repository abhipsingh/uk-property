### Main controller which handles the requests to show
### index pages and the mobile offers page
class SessionsController < ApplicationController
  def create
    render text: request.env['omniauth.auth'].to_yaml
  end
end
