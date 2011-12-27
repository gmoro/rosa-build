class Issue < ActiveRecord::Base
  STATUSES = ['open', 'closed']

  belongs_to :project
  belongs_to :user

  has_many :comments, :as => :commentable
  has_many :subscribes, :as => :subscribeable

  validates :title, :body, :project_id, :presence => true

  #attr_readonly :serial_id

  after_create :set_serial_id
  after_create :subscribe_users
  after_create :deliver_new_issue_notification
  after_create :deliver_issue_assign_notification
  after_update :deliver_issue_assign_notification

  def assign_uname
    user.uname if user
  end

  protected

  def set_serial_id
    self.serial_id = self.project.issues.count
    self.save!
  end

  def deliver_new_issue_notification
    #UserMailer.new_issue_notification(self, self.project.owner).deliver
    #self.project.relations.by_role('admin').each do |rel|
    #  admin = User.find(rel.object_id)
    #  UserMailer.new_issue_notification(self, admin).deliver
    #end

    recipients = collect_recipient_ids
    recipients.each do |recipient_id|
      recipient = User.find(recipient_id)
      UserMailer.new_issue_notification(self, recipient).deliver
    end
  end

  def deliver_issue_assign_notification
    UserMailer.issue_assign_notification(self, self.user).deliver if self.user_id_was != self.user_id
  end

  def subscribe_users
    recipients = collect_recipient_ids
    recipients.each do |recipient_id|
      ss = self.subscribes.build(:user_id => recipient_id)
      ss.save!
    end
  end

  def collect_recipient_ids
    recipients = self.project.relations.by_role('admin').where(:object_type => 'User').map { |rel| rel.read_attribute(:object_id) }
    recipients = recipients | [self.user_id] if self.user_id
    recipients = recipients | [self.project.owner_id] if self.project.owner_type == 'User'
    recipients
  end

end
