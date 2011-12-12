require 'spec_helper'

describe GroupsController do
  before(:each) do
    @group = Factory(:group)
    @another_user  = Factory(:user)
    @create_params = {:group => {:name => 'grp1', :uname => 'un_grp1'}}
    @update_params = {:group => {:name => 'grp2'}}
  end

  context 'for guest' do
    it 'should not be able to perform index action' do
      get :index
      response.should redirect_to(new_user_session_path)
    end

    it 'should not be able to perform update action' do
      put :update, {:id => @group.id}.merge(@update_params)
      response.should redirect_to(new_user_session_path)
    end
  end

  context 'for admin' do
    before(:each) do
      @admin = Factory(:admin)
      set_session_for(@admin)
    end

    it_should_behave_like 'be_able_to_perform_index#groups'
    it_should_behave_like 'be_able_to_perform_update#groups'
    it_should_behave_like 'update_member_relation'

    it 'should be able to perform create action' do
      post :create, @create_params
      response.should redirect_to(group_path( Group.last.id ))
    end

    it 'should change objects count on create' do
      lambda { post :create, @create_params }.should change{ Group.count }.by(1)
    end
  end
end