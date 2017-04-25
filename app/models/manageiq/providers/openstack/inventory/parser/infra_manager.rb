class ManageIQ::Providers::Openstack::Inventory::Parser::InfraManager < ManagerRefresh::Inventory::Parser
  include ManageIQ::Providers::Openstack::RefreshParserCommon::HelperMethods
  include ManageIQ::Providers::Openstack::RefreshParserCommon::Images

  def parse
    object_stores
    miq_templates
    orchestration_stacks
    hosts
  end

  def object_stores
    collector.object_stores.each do |s|
      uid = "#{s.project.id}/#{s.key}"
      store = persister.object_stores.find_or_build(uid)
      store.key = s.key
      store.object_count = s.count
      store.bytes = s.bytes
      collector.objects_from_store(s).each do |o|
        object = persister.objects.find_or_build(o.key)
        object.etag = o.etag
        object.last_modified = o.last_modified
        object.content_length = o.content_length
        object.key = o.key
        object.content_type = o.content_type
        object.container = store
      end
    end
  end

  def server_address(server, key)
    # TODO(lsmola) Nova is missing information which address is primary now,
    # so just taking first. We need to figure out how to identify it if
    # there are multiple.
    server.addresses.fetch_path('ctlplane', 0, key) if server
  end

  def identify_hostname(host)
    purpose = collector.server_resources_by_id(host.uuid)['resource_name']
    return uid unless purpose
    return "#{uid} (#{purpose})"
  end

  def identify_product(host)
    purpose = collector.server_resources_by_id(host.uuid)['resource_name']
    return nil unless purpose

    if purpose == 'NovaCompute'
      'rhel (Nova Compute hypervisor)'
    else
      "rhel (No hypervisor, Host Type is #{purpose})"
    end
  end

  def identify_primary_ip_address(host)
    server = collector.servers_by_id(host.uuid)
    server_address(server, 'addr')
  end

  def identify_primary_mac_address(host)
    server = collector.servers_by_id(host.uuid)
    server_address(server, 'OS-EXT-IPS-MAC:mac_addr')
  end

  def identify_ipmi_address(host)
    host.driver_info["ipmi_address"]
  end

  def identify_hypervisor_hostname(host)
    server = collector.servers_by_id(host.uuid)
    server.try(:name)
  end

  def lookup_power_state(power_state_input)
    case power_state_input
    when "power on"               then "on"
    when "power off", "rebooting" then "off"
    else                               "unknown"
    end
  end

  def lookup_connection_state(power_state_input)
    case power_state_input
    when "power on"               then "connected"
    when "power off", "rebooting" then "disconnected"
    else                               "disconnected"
    end
  end

  def get_extra_attributes(introspection_details)
    return {} if introspection_details.blank? || introspection_details["extra"].nil?
    introspection_details["extra"]
  end

  def hosts
    collector.hosts.each do |h|
      introspection_details = get_introspection_details(h)
      extra_attributes = get_extra_attributes(introspection_details)
      cloud_host_attributes = collector.cloud_ems_hosts_attributes.select do |x|
        hypervisor_hostname && x[:host_name].include?(hypervisor_hostname.downcase)
      end

      host = persister.hosts.find_or_build(h.uuid)
      host.uid_ems = h.uuid
      # host.ems_ref = h.uuid
      # host.ems_ref_obj = host.instance_uuid
      host.operating_system = {:product_name => 'linux'}
      host.maintenance = h.maintenance
      host.maintenance_reason = h.maintenance_reason
      host.hardware = hardware(h)
      host.service_tag = service_tag
      host.vmm_vendor = 'redhat'
      host.vmm_version = nil
      host.vmm_product         = identify_product(h)
      host.ipaddress           = identify_primary_ip_address(h)
      host.hostname            = identify_hostname(h)
      host.mac_address         = identify_primary_mac_address(h)
      host.ipmi_address        = identify_ipmi_address(h)
      host.hypervisor_hostname = identify_hypervisor_hostname(h)
      host.power_state         = lookup_power_state(h)
      host.connection_state    = lookup_connection_state(h)
      host.availability_zone_id = cloud_host_attributes.try(:[], :availability_zone_id)
      # host.ems_cluster = persister.clusters.lazy_find(collector.clusters_by_host_id[h.uuid])
    end
  end

  def clusters
    collector.clusters.each do |c|
      cluster = persister.clusters.find_or_build(c[:uid])
      cluster.ems_ref = c[:uid]
      cluster.uid_ems = c[:uid]
      cluster.name    = c[:name]
      cluster.type    = "ManageIQ::Providers::Openstack::InfraManager::EmsCluster"
    end
  end

  def hardware(host)
    introspection_details = collector.get_introspection_details(host.uuid)
    extra_attributes      = get_extra_attributes(introspection_details)
    cpu_sockets           = extra_attributes.fetch_path('cpu', 'physical', 'number').to_i
    cpu_total_cores       = extra_attributes.fetch_path('cpu', 'logical', 'number').to_i
    cpu_cores_per_socket  = cpu_sockets > 0 ? cpu_total_cores / cpu_sockets : 0

    hardware = persister.hardwares.find_or_build(h.uuid)
    hardware.memory_mb = host.properties['memory_mb']
    hardware.disk_capacity = host.properties['local_gb']
    hardware.cpu_total_cores = cpu_total_cores
    hardware.cpu_sockets = cpu_sockets
    hardware.cpu_cores_per_socket = cpu_cores_per_socket
    hardware.cpu_speed = introspection_details.fetch_path('inventory', 'cpu', 'frequency').to_i
    hardware.cpu_type = extra_attributes.fetch_path('cpu', 'physical_0', 'version')
    hardware.manufacturer = extra_attributes.fetch_path('system', 'product', 'vendor')
    hardware.model = extra_attributes.fetch_path('system', 'product', 'name')
    hardware.number_of_nics = extra_attributes.fetch_path('network').try(:keys).try(:count).to_i
    hardware.bios = extra_attributes.fetch_path('firmware', 'bios', 'version')
    hardware.guest_os_full_name = nil
    hardware.guest_os = nil
    hardware.introspected = !introspection_details.blank?
    hardware.provision_state = host.provision_state.nil? ? "available" : host.provision_state
  end

  def miq_templates
    collector.images.each do |i|
      parent_server_uid = parse_image_parent_id(i)
      image = persister.miq_templates.find_or_build(i.id)
      image.uid_ems = i.id
      image.type = "ManageIQ::Providers::Openstack::InfraManager::Template"
      image.name = i.name || i.id.to_s
      image.vendor = "openstack"
      image.raw_power_state = "never"
      image.template = true
      image.publicly_available = public_image?(i)
      image.cloud_tenants = image_tenants(i)
      image.location = "unknown"
      image.cloud_tenant = persister.cloud_tenants.lazy_find(i.owner) if i.owner
      image.genealogy_parent = persister.vms.lazy_find(parent_server_uid) unless parent_server_uid.nil?

      hardware = persister.hardwares.find_or_build(i.id)
      hardware.vm_or_template = image
      hardware.bitness = image_architecture(i)
      hardware.disk_size_minimum = (i.min_disk * 1.gigabyte)
      hardware.memory_mb_minimum = i.min_ram
      hardware.root_device_type = i.disk_format
      hardware.size_on_disk = i.size
      hardware.virtualization_type = i.properties.try(:[], 'hypervisor_type') || i.attributes['hypervisor_type']
    end
  end

  def orchestration_stack_resources(stack, stack_inventory_object)
    raw_resources = collector.orchestration_resources(stack)
    # reject resources that don't have a physical resource id, because that
    # means they failed to be successfully created
    raw_resources.reject! { |r| r.physical_resource_id.nil? }
    raw_resources.each do |resource|
      uid = resource.physical_resource_id
      o = persister.orchestration_stacks_resources.find_or_build(uid)
      o.ems_ref = uid
      o.logical_resource = resource.logical_resource_id
      o.physical_resource = resource.physical_resource_id
      o.resource_category = resource.resource_type
      o.resource_status = resource.resource_status
      o.resource_status_reason = resource.resource_status_reason
      o.last_updated = resource.updated_time
      o.stack = stack_inventory_object

      if %w(OS::TripleO::Server OS::Nova::Server).include?(resource.resource_type) && !stack.parent.nil?
        cluster = persister.clusters.find_or_build(stack.parent)
        cluster.ems_ref = stack.parent
        cluster.uid_ems = stack.parent
        cluster.name    = persister.orchestration_stacks.lazy_find(stack.parent, :key => :name)
        cluster.type    = "ManageIQ::Providers::Openstack::InfraManager::EmsCluster"
      end
    end
  end

  def orchestration_stack_parameters(stack, stack_inventory_object)
    collector.orchestration_parameters(stack).each do |param_key, param_val|
      uid = compose_ems_ref(stack.id, param_key)
      o = persister.orchestration_stacks_parameters.find_or_build(uid)
      o.ems_ref = uid
      o.name = param_key
      o.value = param_val
      o.stack = stack_inventory_object
    end
  end

  def orchestration_stack_outputs(stack, stack_inventory_object)
    collector.orchestration_outputs(stack).each do |output|
      uid = compose_ems_ref(stack.id, output['output_key'])
      o = persister.orchestration_stacks_outputs.find_or_build(uid)
      o.ems_ref = uid
      o.key = output['output_key']
      o.value = output['output_value']
      o.description = output['description']
      o.stack = stack_inventory_object
    end
  end

  def orchestration_template(stack)
    template = collector.orchestration_template(stack)
    if template
      o = persister.orchestration_templates.find_or_build(stack.id)
      o.type = stack.template.format == "HOT" ? "OrchestrationTemplateHot" : "OrchestrationTemplateCfn"
      o.name = stack.stack_name
      o.description = stack.template.description
      o.content = stack.template.content
      o.orderable = false
      o
    end
  end

  def orchestration_stacks
    collector.orchestration_stacks.each do |stack|
      o = persister.orchestration_stacks.find_or_build(stack.id.to_s)
      o.type = "ManageIQ::Providers::Openstack::InfraManager::OrchestrationStack"
      o.name = stack.stack_name
      o.description = stack.description
      o.status = stack.stack_status
      o.status_reason = stack.stack_status_reason
      o.parent = persister.orchestration_stacks.lazy_find(stack.parent)
      o.orchestration_template = orchestration_template(stack)
      o.cloud_tenant = persister.cloud_tenants.lazy_find(stack.service.current_tenant["id"])

      orchestration_stack_resources(stack, o)
      orchestration_stack_outputs(stack, o)
      orchestration_stack_parameters(stack, o)
    end
  end

  def make_instance_disk(hardware, size, location, name)
    disk = persister.disks.find_or_build_by(
      :hardware    => hardware,
      :device_name => name
    )
    disk.device_name = name
    disk.device_type = "disk"
    disk.controller_type = "openstack"
    disk.size = size
    disk.location = location
    disk
  end

  # Compose an ems_ref combining some existing keys
  def compose_ems_ref(*keys)
    keys.join('_')
  end

  # Identify whether the given image is publicly available
  def public_image?(image)
    # Glance v1
    return image.is_public if image.respond_to? :is_public
    # Glance v2
    image.visibility != 'private' if image.respond_to? :visibility
  end

  # Identify whether the given image has a 32 or 64 bit architecture
  def image_architecture(image)
    architecture = image.properties.try(:[], 'architecture') || image.attributes['architecture']
    return nil if architecture.blank?
    # Just simple name to bits, x86_64 will be the most used, we should probably support displaying of
    # architecture name
    architecture.include?("64") ? 64 : 32
  end

  # Identify the id of the parent of this image.
  def parse_image_parent_id(image)
    if collector.image_service.name == :glance
      # What version of openstack is this glance v1 on some old openstack version?
      return image.copy_from["id"] if image.respond_to?(:copy_from) && image.copy_from
      # Glance V2
      return image.instance_uuid if image.respond_to? :instance_uuid
      # Glance V1
      image.properties.try(:[], 'instance_uuid')
    elsif image.server
      # Probably nova images?
      image.server["id"]
    end
  end

  def image_tenants(image)
    tenants = []
    if public_image?(image)
      # For public image we will fill a relation to all tenants,
      # since calling the members api for a public image throws a 403.
      collector.tenants.each do |t|
        tenants << persister.cloud_tenants.lazy_find(t.id)
      end
    else
      # Add owner of the image
      tenants << persister.cloud_tenants.lazy_find(image.owner) if image.owner
      # Add members of the image
      unless (members = image.members).blank?
        tenants += members.map { |x| persister.cloud_tenants.lazy_find(x['member_id']) }
      end
    end
    tenants
  end
end
