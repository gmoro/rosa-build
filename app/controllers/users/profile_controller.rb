class Users::ProfileController < Users::BaseController
  include PaginateHelper

  skip_before_action :authenticate_user!, only: :show if APP_CONFIG['anonymous_access']

  def show
    authorize @user
    respond_to do |format|
      format.html do
        @groups = @user.groups.order(:uname)
      end
      format.json do
        @projects = @user.own_projects.search(params[:term]).recent
        case params[:visibility]
        when 'open'
          @projects = @projects.opened
        when 'hidden'
          @projects = ProjectPolicy::Scope.new(current_user, @projects.by_visibilities('hidden')).read
        else
          @projects = ProjectPolicy::Scope.new(current_user, @projects).read
        end
        @total_items  = @projects.count
        @projects     = @projects.paginate(paginate_params)
      end
    end
  end

end
