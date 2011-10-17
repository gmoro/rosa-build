class ApplicationController < ActionController::Base
  protect_from_forgery
  layout :layout_by_resource

  protected
    def layout_by_resource
      if devise_controller?
        "sessions"
      else
        "application"
      end
    end

    def get_acter
      return User.find params[:user_id] if params[:user_id]
      return Group.find params[:group_id] if params[:group_id]
      return current_user
    end

    def authenticate_build_service!
      if request.remote_ip != APP_CONFIG['build_service_ip']
        render :nothing => true, :status => 403
      end
    end

    def authenticate_product_builder!
      if request.remote_ip != APP_CONFIG['product_builder_ip']
        render :nothing => true, :status => 403
      end
    end
end
