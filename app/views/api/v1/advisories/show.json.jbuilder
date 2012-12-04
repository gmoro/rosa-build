json.advisory do |json|
  json.partial! 'advisory', :advisory => @advisory, :json => json
  json.created_at @advisory.created_at.to_i
  json.updated_at @advisory.updated_at.to_i
  json.(@advisory, :update_type)
  json.references @advisory.references.split('\n')
  
  json.build_lists @advisory.build_lists do |json_build_list, build_list|
    json_build_list.(build_list, :id)
    json_build_list.url api_v1_build_list_path(build_list.id, :format => :json)
  end

  json.affected_in @packages_info do |json_platform, package_info|
    json.partial! 'api/v1/platforms/platform',
        :platform => package_info[0], :json => json_platform

    json_platform.projects package_info[1] do |json_project, info|
      json.partial! 'api/v1/projects/project',
        :project => info[0], :json => json_project
        
      packages = info[1]
      json_project.srpm packages[:srpm]
      json_project.rpm packages[:rpm]
    end
  end

end