json.build_list do
  json.(@build_list, :id, :container_status, :status, :duration)
  json.(@build_list, :update_type)
  json.updated_at @build_list.updated_at.strftime('%Y-%m-%d %H:%M:%S UTC')

  if !@build_list.in_work? && @build_list.started_at
    json.human_duration @build_list.human_duration
  elsif @build_list.in_work?
    json.human_duration "#{@build_list.human_current_duration} / #{@build_list.human_average_build_time}"
  end

  json.build_log_url log_build_list_path(@build_list)

  json.can_cancel @build_list.can_cancel?
  json.can_create_container @build_list.can_create_container?
  json.can_reject_publish @build_list.can_reject_publish?

  json.extra_build_lists_published @build_list.extra_build_lists_published?
  json.can_publish_in_future can_publish_in_future?(@build_list)


  json.container_path container_url if @build_list.container_published?

  json.publisher do
    json.fullname @build_list.publisher.try(:fullname)
    json.path user_path(@build_list.publisher)
  end if @build_list.publisher

  json.advisory do
    json.(@build_list.advisory, :description, :advisory_id)
    json.path advisory_path(@build_list.advisory)
  end if @build_list.advisory

  json.logs (@build_list.results || []) do |result|
    json.file_name result['file_name']
    json.size result['size']
    json.url "#{APP_CONFIG['file_store_url']}/api/v1/file_stores/#{result['sha1']}"
  end if @build_list.new_core?

  json.packages @build_list.packages do |package|
    json.(package, :id, :name, :fullname, :release, :version, :sha1)
    json.url "#{APP_CONFIG['file_store_url']}/api/v1/file_stores/#{package.sha1}" if package.sha1
  end if @build_list.packages.present?

  json.item_groups do |group|
    @item_groups.each_with_index do |group, level|
      json.group group do |item|
        json.(item, :name, :status)
        json.path build_list_item_version_link item
        json.level level
      end
    end
  end if @item_groups.present?

end
