class ConfirmationsController < Devise::ConfirmationsController

  private

  def after_confirmation_path_for(resource_name, resource)
    resource_id = resource.id
    profile_type = resource.profile_type
    @detail = TempPropertyDetail.where(user_id: resource_id).select([:id])
    user_id = resource.id
    id = @detail.first.id
    properties_sign_confirm_url(user_id: user_id, id: id)
  end

end