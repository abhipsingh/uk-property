module PropertiesHelper
  def email
    @user['info']['email'] if @user && @user['info']
  end

  def first_name
    @user['info']['first_name'] if @user && @user['info']
  end
  
  def last_name
    @user['info']['last_name'] if @user && @user['info']
  end

  def image
    @user['info']['image'] if @user && @user['info']
  end

  def uid
    @user['uid'] if @user
  end

  def provider
    @user['provider'] if @user
  end

  def detail
    if @detail
      @detail.id 
    else
      @detail_id
    end
  end

  def resource_name
    :property_user
  end

  def resource
    if @property_user
      @resource ||= @property_user
    else
      @resource ||= PropertyUser.new
    end
  end

  def devise_mapping
    @devise_mapping ||= Devise.mappings[:property_user]
  end
end