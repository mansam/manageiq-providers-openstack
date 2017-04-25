class ManageIQ::Providers::Openstack::Inventory::Collector::InfraManager < ManagerRefresh::Inventory::Collector
  include ManageIQ::Providers::Openstack::RefreshParserCommon::HelperMethods
  include Vmdb::Logging

  def connection
    @os_handle ||= manager.openstack_handle
    @connection ||= manager.connect
  end

  def compute_service
    connection
  end

  def image_service
    @image_service ||= manager.openstack_handle.detect_image_service
  end

  def identity_service
    @identity_service ||= manager.openstack_handle.identity_service
  end

  def introspection_service
    @introspection_service ||= manager.openstack_handle.detect_introspection_service
  end

  def storage_service
    @storage_service ||= manager.openstack_handle.detect_storage_service
  end

  def orchestration_service
    @orchestration_service ||= manager.openstack_handle.detect_orchestration_service
  end

  def servers
    @servers ||= @connection.handled_list(:servers)
  end

  def hosts
    @hosts ||= @baremetal_service.handled_list(:nodes)
  end

  def clouds
    @ems.provider.try(:cloud_ems)
  end

  def cloud_ems_hosts_attributes
    hosts_attributes = []
    return hosts_attributes unless clouds

    clouds.each do |cloud_ems|
      compute_hosts = nil
      begin
        cloud_ems.with_provider_connection do |connection|
          compute_hosts = connection.hosts.select { |x| x.service_name == "compute" }
        end
      rescue => err
        _log.error "Error Class=#{err.class.name}, Message=#{err.message}"
        $log.error err.backtrace.join("\n")
        # Just log the error and continue the refresh, we don't want error in cloud side to affect infra refresh
        next
      end

      compute_hosts.each do |compute_host|
        # We need to take correct zone id from correct provider, since the zone name can be the same
        # across providers
        availability_zone_id = cloud_ems.availability_zones.find_by(:name => compute_host.zone).try(:id)
        hosts_attributes << {:host_name => compute_host.host_name, :availability_zone_id => availability_zone_id}
      end
    end
    hosts_attributes
  end

  def images
    @images ||= image_service.handled_list(:images)
  end

  def tenants
    @tenants ||= manager.openstack_handle.accessible_tenants
  end

  def object_stores
    @object_stores ||= storage_service.handled_list(:directories)
  end

  def objects_from_store(store)
    safe_list { store.files }
  end

  def orchestration_stacks
    return [] unless orchestration_service
    # TODO(lsmola) We need a support of GET /{tenant_id}/stacks/detail in FOG, it was implemented here
    # https://review.openstack.org/#/c/35034/, but never documented in API reference, so right now we
    # can't get list of detailed stacks in one API call.
    orchestration_service.handled_list(:stacks, :show_nested => true).collect(&:details)
  rescue Excon::Errors::Forbidden
    # Orchestration service is detected but not open to the user
    $log.warn("Skip refreshing stacks because the user cannot access the orchestration service")
    []
  end

  def orchestration_outputs(stack)
    safe_list { stack.outputs }
  end

  def orchestration_parameters(stack)
    safe_list { stack.parameters }
  end

  def orchestration_resources(stack)
    safe_list { stack.resources }
  end

  def orchestration_template(stack)
    safe_call { stack.template }
  end
end
