class EventLogObserver < ActiveRecord::Observer
  observe :user, :private_user, :platform, :repository, :project, :product, :build_list, :auto_build_list

  def after_create(record)
    ActiveSupport::Notifications.instrument("event_log.observer", :object => record)
  end

  def before_update(record)
    case record.class
    when BuildList
      if record.status_changed? and record.status == BUILD_CANCELED
        ActiveSupport::Notifications.instrument("event_log.observer", :object => record)
      end
    # when Platform
    #   if record.visibility_changed?
    #     ActiveSupport::Notifications.instrument "event_log.observer", :object => record,
    #       :message => I18n.t("activerecord.attributes.platform.visibility_types.#{record.visibility}")
    #   end
    end
  end

  def after_destroy(record)
    ActiveSupport::Notifications.instrument("event_log.observer", :object => record)
  end
end
