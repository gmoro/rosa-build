require 'spec_helper'

describe ProjectsController do
	before(:each) do
    stub_rsync_methods

    @project = Factory(:project)
    @another_user = Factory(:user)
    @create_params = {:project => {:name => 'pro'}}
    @update_params = {:project => {:name => 'pro2'}}
	end

	context 'for guest' do
    it 'should not be able to perform index action' do
      get :index
      response.should redirect_to(new_user_session_path)
    end

    it 'should not be able to perform update action' do
      put :update, {:id => @project.id}.merge(@update_params)
      response.should redirect_to(new_user_session_path)
    end
  end

  context 'for admin' do
  	before(:each) do
  		@admin = Factory(:admin)
  		set_session_for(@admin)
		end

    it_should_behave_like 'projects user with writer rights'
    it_should_behave_like 'projects user with reader rights'

    it 'should be able to perform create action' do
      post :create, @create_params
      response.should redirect_to(project_path( Project.last.id ))
    end

    it 'should change objects count on create' do
      lambda { post :create, @create_params }.should change{ Project.count }.by(1)
    end
  end

  context 'for owner user' do
  	before(:each) do
  		@user = Factory(:user)
  		set_session_for(@user)
  		@project.update_attribute(:owner, @user)
  		@project.relations.create!(:object_type => 'User', :object_id => @user.id, :role => 'admin')
		end

    it_should_behave_like 'projects user with writer rights'
    it_should_behave_like 'user with rights to view projects'

    it 'should be able to perform destroy action' do
      delete :destroy, {:id => @project.id}
      response.should redirect_to(@project.owner)
    end

    it 'should change objects count on destroy' do
      lambda { delete :destroy, :id => @project.id }.should change{ Project.count }.by(-1)
    end

    it 'should not be able to fork project' do
      post :fork, :id => @project.id
      response.should redirect_to(forbidden_path)
    end
  end

  context 'for reader user' do
  	before(:each) do
  		@user = Factory(:user)
  		set_session_for(@user)
  		@project.relations.create!(:object_type => 'User', :object_id => @user.id, :role => 'reader')
		end

    it_should_behave_like 'projects user with reader rights'

    it 'should be able to perform show action' do
      get :show, :id => @project.id
      response.should render_template(:show)
    end

  end

  context 'for writer user' do
  	before(:each) do
  		@user = Factory(:user)
  		set_session_for(@user)
  		@project.relations.create!(:object_type => 'User', :object_id => @user.id, :role => 'writer')
		end

    it_should_behave_like 'projects user with writer rights'
    it_should_behave_like 'projects user with reader rights'
  end

  context 'search projects' do

    before(:each) do
      @admin = Factory(:admin)
      @project1 = Factory(:project, :name => 'perl-debug')
      @project2 = Factory(:project, :name => 'perl')
      set_session_for(@admin)
    end

    it 'should return projects in right order' do
      get :index, :query => 'per'
      assigns(:projects).should eq([@project2, @project1])
    end
  end
end
