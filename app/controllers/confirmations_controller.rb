class ConfirmationsController < Devise::ConfirmationsController

  private

  def after_confirmation_path_for(resource_name, resource)
    resource_id = resource.id
    profile_type = resource.profile_type
    @detail = nil
    if profile_type == 'Vendor'
      @detail = TempPropertyDetail.where(vendor_id: resource_id).select([:id])
    elsif profile_type == 'Agent'
      @detail = TempPropertyDetail.where(agent_id: resource_id).select([:id])
    end
    user_id = resource.id
    id = @detail.first.id
    properties_sign_confirm_url(user_id: user_id, id: id)
  end

end