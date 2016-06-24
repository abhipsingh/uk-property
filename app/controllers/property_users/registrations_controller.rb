class PropertyUsers::RegistrationsController < Devise::RegistrationsController

  before_filter :configure_permitted_parameters

  def create
    build_resource(sign_up_params)
    @user.email = params[:property_user][:email]
    @user.save
    if @user.save
      set_flash_message(:notice, :success, kind: 'email') if is_navigational_format?
      sign_in_and_redirect @user, event: :authentication
    else
      super
      session['omniauth'] = nil unless @user.new_record?
    end
  end

  protected
  def configure_permitted_parameters
    devise_parameter_sanitizer.for(:sign_up).push(:full_name)
    devise_parameter_sanitizer.for(:account_update).push(:full_name)
  end

  private
  def build_resource(*args)
    super
    if session['omniauth']
      @user = PropertyUser.from_omniauth(session['omniauth'])
      @user.valid?
    end

  end

end
