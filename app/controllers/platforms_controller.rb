# -*- encoding : utf-8 -*-
class PlatformsController < ApplicationController
  before_filter :authenticate_user!, :except => :easy_urpmi
  before_filter :find_platform, :only => [:freeze, :unfreeze, :clone, :edit, :destroy]
  before_filter :get_paths, :only => [:new, :create, :clone]
  
  load_and_authorize_resource
  autocomplete :user, :uname

  def build_all
    @platform.repositories.each do |repository|
      repository.projects.each do |project|
        project.delay.build_for(@platform, current_user)
      end
    end

    redirect_to(platform_path(@platform), :notice => t("flash.platform.build_all_success"))
  end

  def index
    @platforms = Platform.accessible_by(current_ability).paginate(:page => params[:platform_page])
  end

  def easy_urpmi
    @platforms = Platform.where(:distrib_type => APP_CONFIG['distr_types'].first, :visibility => 'open', :platform_type => 'main')
    respond_to do |format|
      format.json do
        render :json => {
          :platforms => @platforms.map do |p|
                          {:name => p.name,
                           :architectures => ['i586', 'x86_64'],
                           :repositories => p.repositories.map(&:name),
                           :url => p.public_downloads_url(request.host_with_port)}
                        end
        }
      end
    end
  end

  def show
    @platform = Platform.find params[:id], :include => :repositories
    @repositories = @platform.repositories
    @members = @platform.members.uniq
  end

  def new
    @platform = Platform.new
    @admin_uname = current_user.uname
    @admin_id = current_user.id
  end
  
  def edit
    @admin_id = @platform.owner.id
    @admin_uname = @platform.owner.uname
  end

  def create
    @platform = Platform.new params[:platform]
    @admin_id = params[:admin_id]
    @admin_uname = params[:admin_uname]
    @platform.owner = @admin_id.blank? ? get_owner : User.find(@admin_id)

    if @platform.save
      flash[:notice] = I18n.t("flash.platform.saved")
      redirect_to @platform
    else
      flash[:error] = I18n.t("flash.platform.save_error")
      render :action => :new
    end
  end

  def update
    @admin_id = params[:admin_id]
    @admin_uname = params[:admin_uname]

    if @platform.update_attributes(
      :owner => @admin_id.blank? ? get_owner : User.find(@admin_id),
      :description => params[:platform][:description],
      :released => params[:platform][:released]
    )
      flash[:notice] = I18n.t("flash.platform.saved")
      redirect_to @platform
    else
      flash[:error] = I18n.t("flash.platform.save_error")
      render :action => :new
    end
  end

  def freeze
    @platform.released = true
    if @platform.save
      flash[:notice] = I18n.t("flash.platform.freezed")
    else
      flash[:notice] = I18n.t("flash.platform.freeze_error")
    end

    redirect_to @platform
  end

  def unfreeze
    @platform.released = false
    if @platform.save
      flash[:notice] = I18n.t("flash.platform.unfreezed")
    else
      flash[:notice] = I18n.t("flash.platform.unfreeze_error")
    end

    redirect_to @platform
  end

  def clone
    @cloned = Platform.new
    @cloned.name = @platform.name + "_clone"
    @cloned.description = @platform.description + "_clone"
  end

  def make_clone
    @cloned = @platform.make_clone(:name => params[:platform]['name'], :description => params[:platform]['description'],
                                   :owner_id => current_user.id, :owner_type => current_user.class.to_s)
    if @cloned.persisted? # valid?
      flash[:notice] = I18n.t("flash.platform.clone_success")
      redirect_to @cloned
    else
      raise @cloned.repositories.first.inspect
      flash[:error] = @cloned.errors.full_messages.join('. ')
      render 'clone'
    end
  end

  def destroy
    @platform.destroy if @platform

    flash[:notice] = t("flash.platform.destroyed")
    redirect_to root_path
  end
  
  def forbidden
  end

  protected
    def get_paths
      if params[:user_id]
        @user = User.find params[:user_id]
        @platforms_path = user_platforms_path @user
        @new_platform_path = new_user_platform_path @user
      elsif params[:group_id]
        @group = Group.find params[:group_id]
        @platforms_path = group_platforms_path @group
        @new_platform_path = new_group_platform_path @group
      else
        @platforms_path = platforms_path
        @new_platform_path = new_platform_path
      end
    end

    def find_platform
      @platform = Platform.find params[:id]
    end
end
