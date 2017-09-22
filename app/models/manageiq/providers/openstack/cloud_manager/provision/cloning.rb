module ManageIQ::Providers::Openstack::CloudManager::Provision::Cloning
  def do_clone_task_check(clone_task_ref)
    source.with_provider_connection do |openstack|
      instance = openstack.handled_list(:servers).detect { |s| s.id == clone_task_ref }
      status   = instance.state.downcase.to_sym

      if status == :error
        raise MiqException::MiqProvisionError, "An error occurred while provisioning Instance #{instance.name}"
      end
      return true if status == :active
      return false, status
    end
  end

  def prepare_for_clone_task
    clone_options = super

    clone_options[:name]              = dest_name
    clone_options[:image_ref]         = source.ems_ref
    clone_options[:flavor_ref]        = instance_type.ems_ref
    clone_options[:availability_zone] = nil if dest_availability_zone.kind_of?(ManageIQ::Providers::Openstack::CloudManager::AvailabilityZoneNull)
    clone_options[:security_groups]   = security_groups.collect(&:ems_ref)
    clone_options[:nics]              = configure_network_adapters unless configure_network_adapters.blank?

    clone_options[:block_device_mapping_v2] = configure_volumes unless configure_volumes.blank?

    clone_options
  end

  def log_clone_options(clone_options)
    _log.info("Provisioning [#{source.name}] to [#{clone_options[:name]}]")
    _log.info("Source Image:                    [#{clone_options[:image_ref]}]")
    _log.info("Destination Availability Zone:   [#{clone_options[:availability_zone]}]")
    _log.info("Flavor:                          [#{clone_options[:flavor_ref]}]")
    _log.info("Guest Access Key Pair:           [#{clone_options[:key_name]}]")
    _log.info("Security Group:                  [#{clone_options[:security_groups]}]")
    _log.info("Network:                         [#{clone_options[:nics]}]")

    dump_obj(clone_options, "#{_log.prefix} Clone Options: ", $log, :info)
    dump_obj(options, "#{_log.prefix} Prov Options:  ", $log, :info, :protected => {:path => workflow_class.encrypted_options_field_regs})
  end

  def start_clone(clone_options)
    connection_options = {:tenant_name => options[:cloud_tenant][1]} if options[:cloud_tenant].kind_of? Array
    if source.kind_of?(ManageIQ::Providers::Openstack::CloudManager::VolumeTemplate)
      # remove the image_ref parameter from the options since it actually refers
      # to a volume, and then overwrite the default root volume with the volume
      # we are trying to boot the instance from
      clone_options.delete(:image_ref)
      clone_options[:block_device_mapping_v2][0][:source_type] = "volume"
      clone_options[:block_device_mapping_v2][0][:size] = nil
      clone_options[:block_device_mapping_v2][0][:delete_on_termination] = false
      clone_options[:block_device_mapping_v2][0][:destination_type] = "volume"
      # adjust the parameters to make booting from a volume work.
    end
    source.with_provider_connection(connection_options) do |openstack|
      instance = openstack.servers.create(clone_options)
      return instance.id
    end
  end
end
