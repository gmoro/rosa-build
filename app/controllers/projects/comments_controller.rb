class Projects::CommentsController < Projects::BaseController
  before_action :authenticate_user!
  load_and_authorize_resource :project
  before_action :find_commentable
  before_action :find_or_build_comment
  load_and_authorize_resource new: :new_line

  include CommentsHelper

  def create
    respond_to do |format|
      if !@comment.set_additional_data params
        format.json {
                      render json: {
                                     message: I18n.t("flash.comment.save_error"),
                                     error:   @comment.errors.full_messages
                                   }
                    }
      elsif @comment.save
        format.json {}
      else
        format.json { render json: { message: I18n.t("flash.comment.save_error") }, status: 422 }
      end
    end
  end

  def edit
  end

  def update
    respond_to do |format|
      if @comment.update_attributes(params[:comment])
        format.json { render json: {message:t('flash.comment.updated'), body: view_context.markdown(@comment.body)} }
      else
        format.json { render json: {message:t('flash.comment.error_in_updating')}, status: 422 }
      end
    end
  end

  def destroy
    respond_to do |format|
      if @comment.present? && @comment.destroy
        format.json { render json: {message: I18n.t('flash.comment.destroyed')} }
      else
        format.json {
          render json: {message: t('flash.comment.error_in_deleting')}, status: 422 }
      end
    end
  end

  protected

  def find_commentable
    @commentable = params[:issue_id].present? && @project.issues.find_by(serial_id: params[:issue_id]) ||
                   params[:commit_id].present? && @project.repo.commit(params[:commit_id])
  end

  def find_or_build_comment
    @comment = params[:id].present? && Comment.where(automatic: false).find(params[:id]) ||
               current_user.comments.build(params[:comment]) {|c| c.commentable = @commentable; c.project = @project}
  end
end
