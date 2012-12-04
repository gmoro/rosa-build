class PullRequest < ActiveRecord::Base
  STATUSES = %w(ready already blocked merged closed)
  belongs_to :issue, :autosave => true, :dependent => :destroy, :touch => true, :validate => true
  belongs_to :to_project, :class_name => 'Project', :foreign_key => 'to_project_id'
  belongs_to :from_project, :class_name => 'Project', :foreign_key => 'from_project_id'
  delegate :user, :user_id, :title, :body, :serial_id, :assignee, :status, :to_param,
    :created_at, :updated_at, :comments, :status=, :to => :issue, :allow_nil => true

  validates :from_project, :to_project, :presence => true
  validate :uniq_merge, :if => Proc.new { |pull| pull.to_project.present? }
  validates_each :from_ref, :to_ref do |record, attr, value|
    check_ref record, attr, value
  end

  before_create :clean_dir
  before_create :set_add_data
  after_destroy :clean_dir

  accepts_nested_attributes_for :issue
  attr_accessible :issue_attributes, :to_ref, :from_ref

  scope :needed_checking, includes(:issue).where(:issues => {:status => ['open', 'blocked', 'ready']})

  state_machine :status, :initial => :open do
    event :ready do
      transition [:ready, :open, :blocked] => :ready
    end

    event :already do
      transition [:ready, :open, :blocked] => :already
    end

    event :block do
      transition [:ready, :open, :blocked] => :blocked
    end

    event :merging do
      transition :ready => :merged
    end

    event :close do
      transition [:ready, :open, :blocked] => :closed
    end

    event :reopen do
      transition :closed => :open
    end
  end

  def check(do_transaction = true)
    res = merge
    new_status = case res
                 when /Already up-to-date/
                   'already'
                 when /Merge made by/
                   system("cd #{path} && git reset --hard HEAD^") # remove merge commit
                   'ready'
                 when /Automatic merge failed/
                   system("cd #{path} && git reset --hard HEAD") # clean git index
                   'block'
                 else
                   raise res
                 end

    if do_transaction
      new_status == 'already' ? (ready; merging) : send(new_status)
      self.update_inline_comments
    else
      self.status = new_status == 'block' ? 'blocked' : new_status
    end
  end

  def merge!(who)
    return false unless can_merging?
    Dir.chdir(path) do
      system "git config user.name \"#{who.uname}\" && git config user.email \"#{who.email}\""
      if merge
        system("git push origin HEAD")
        system("git reset --hard HEAD^") # for diff maybe FIXME
        set_user_and_time who
        merging
      end
    end
  end

  def path
    last_part = [id, from_project_owner_uname, from_project_name].compact.join('-')
    File.join(APP_CONFIG['git_path'], "#{new_record? ? 'temp_' : ''}pull_requests", to_project.owner.uname, to_project.name, last_part)
  end

  def from_branch
    if to_project_id != from_project_id
      "head_#{from_ref}"
    else
      from_ref
    end
  end

  def common_ancestor
    return @common_ancestor if @common_ancestor
    base_commit = repo.commits(to_ref).first
    @common_ancestor = repo.commit(repo.git.merge_base({}, base_commit, from_commit)) || base_commit
  end
  alias_method :to_commit, :common_ancestor

  def diff_stats
    @diff_stats ||= repo.diff_stats(to_commit.id, from_commit.id)
  end

  # FIXME maybe move to warpc/grit?
  def diff
    @diff ||= repo.diff(to_commit.id, from_commit.id)
  end

  def set_user_and_time user
    issue.closed_at = Time.now.utc
    issue.closer = user
  end

  def self.check_ref(record, attr, value)
    project = attr == :from_ref ? record.from_project : record.to_project
    return if project.blank?
    if record.to_project.repo.commits.count > 0
      record.errors.add attr, I18n.t('projects.pull_requests.wrong_ref') unless project.repo.branches_and_tags.map(&:name).include?(value)
    else
      record.errors.add attr, I18n.t('projects.pull_requests.empty_repo')
    end
  end

  def uniq_merge
    if to_project && to_project.pull_requests.needed_checking
         .where(:from_project_id => from_project_id,
                :to_ref => to_ref, :from_ref => from_ref)
         .where('pull_requests.id <> :id or :id is null', :id => id).count > 0
      errors.add(:base_branch, I18n.t('projects.pull_requests.duplicate', :from_ref => from_ref))
    end
  end

  def repo
    return @repo if @repo.present? #&& !id_changed?
    @repo = Grit::Repo.new path
  end

  def from_commit
    repo.commits(from_branch).first
  end

  protected

  def merge
    clone
    message = "Merge pull request ##{serial_id} from #{from_project_owner_uname}/#{from_project_name}:#{from_ref}\r\n #{title}"
    %x(cd #{path} && git checkout #{to_ref} && git merge --no-ff #{from_branch} -m '#{message}')
  end

  def clone
    git = Grit::Git.new(path)
    if new_record? || !git.exist?
      #~ FileUtils.mkdir_p(path)
      #~ system("git clone --local --no-hardlinks #{to_project.path} #{path}")
      options = {:bare => false, :shared => false, :branch => to_ref} # shared?
      `rm -rf #{path}`
      git.fs_mkdir('..')
      git.clone(options, to_project.path, path)
      if to_project != from_project
        Dir.chdir(path) do
          system 'git', 'remote', 'add', 'head', from_project.path
        end
      end
      clean # Need testing
    end

    Dir.chdir(path) do
      system 'git', 'checkout', to_ref
      system 'git', 'pull',  'origin', to_ref
      if to_project_id == from_project_id
        system 'git', 'checkout', from_ref
        system 'git', 'pull', 'origin', from_ref
      else
        system 'git', 'fetch', 'head', "+#{from_ref}:#{from_branch}"
      end
    end
    # TODO catch errors
  end

  def clean
    Dir.chdir(path) do
      to_project.repo.branches.each {|branch| system 'git', 'checkout', branch.name}
      system 'git', 'checkout', to_ref

      to_project.repo.branches.each do |branch|
        system 'git', 'branch', '-D', branch.name unless [to_ref, from_branch].include? branch.name
      end
      to_project.repo.tags.each do |tag|
        system 'git', 'tag', '-d', tag.name unless [to_ref, from_branch].include? tag.name
      end
    end
  end

  def clean_dir
    FileUtils.rm_rf path
  end

  def update_inline_comments
    self.comments.each do |c|
      if c.data.present? # maybe need add new column 'actual'?
        c.actual_inline_comment? diff, true
        c.save
      end
    end
  end

  def set_add_data
    self.from_project_owner_uname = from_project.owner.uname
    self.from_project_name = from_project.name
  end
end