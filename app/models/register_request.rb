# -*- encoding : utf-8 -*-
class RegisterRequest < ActiveRecord::Base
  default_scope order('created_at ASC')

  scope :rejected, where(:rejected => true)
  scope :approved, where(:approved => true)
  scope :unprocessed, where(:approved => false, :rejected => false)

  # before_create :generate_token
  before_update :invite_approve_notification

  validates :email, :presence => true, :uniqueness => {:case_sensitive => false}, :format => { :with => /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i }

  protected

  def generate_token
    self.token = Digest::SHA1.hexdigest(name + email + Time.now.to_s + rand.to_s)
  end

  def invite_approve_notification
    if approved_changed? and approved == true
      generate_token
      UserMailer.invite_approve_notification(self).deliver
    end
  end
end