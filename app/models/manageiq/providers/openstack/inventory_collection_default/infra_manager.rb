class ManageIQ::Providers::Openstack::InventoryCollectionDefault::InfraManager < ManagerRefresh::InventoryCollectionDefault::CloudManager
  class << self

    def clusters(extra_attributes = {})
      attributes = {
        :model_class                 => ManageIQ::Providers::Openstack::InfraManager::EmsCluster,
        :association                 => :clusters,
        :inventory_object_attributes => [
          :type,
          :uid_ems,
          :name
        ]
      }
      attributes.merge!(extra_attributes)
    end

    def disks(extra_attributes = {})
      attributes = {
        :inventory_object_attributes => [
          :device_name,
          :device_type,
          :controller_type,
          :size,
          :location
        ]
      }
      super(attributes.merge!(extra_attributes))
    end

    def hardwares(extra_attributes = {})
      attributes = {
        :inventory_object_attributes => [
          :vm_or_template,
          :cpu_sockets,
          :cpu_total_cores,
          :cpu_speed,
          :memory_mb,
          :disk_capacity,
          :bitness,
          :disk_size_minimum,
          :memory_mb_minimum,
          :root_device_type,
          :size_on_disk,
          :virtualization_type
        ]
      }
      super(attributes.merge!(extra_attributes))
    end

    def miq_templates(extra_attributes = {})
      attributes = {
        :model_class                 => ManageIQ::Providers::Openstack::InfraManager::Template,
        :inventory_object_attributes => [
          :type,
          :uid_ems,
          :name,
          :vendor,
          :raw_power_state,
          :template,
          :publicly_available,
          :location,
          :cloud_tenant,
          :cloud_tenants,
          :genealogy_parent
        ]
      }
      super(attributes.merge!(extra_attributes))
    end

    def networks(extra_attributes = {})
      attributes = {
        :inventory_object_attributes => [
          :hardware,
          :description,
          :ipaddress
        ]
      }
      super(attributes.merge!(extra_attributes))
    end

    def orchestration_stacks_outputs(extra_attributes = {})
      attributes = {
        :inventory_object_attributes => [
          :ems_ref,
          :key,
          :value,
          :description,
          :stack
        ]
      }
      super(attributes.merge!(extra_attributes))
    end

    def orchestration_stacks_parameters(extra_attributes = {})
      attributes = {
        :inventory_object_attributes => [
          :ems_ref,
          :name,
          :value,
          :stack
        ]
      }
      super(attributes.merge!(extra_attributes))
    end

    def orchestration_stacks_resources(extra_attributes = {})
      attributes = {
        :inventory_object_attributes => [
          :ems_ref,
          :logical_resource,
          :physical_resource,
          :resource_category,
          :resource_status,
          :resource_status_reason,
          :last_updated,
          :stack
        ]
      }
      super(attributes.merge!(extra_attributes))
    end

    def orchestration_stacks(extra_attributes = {})
      attributes = {
        :model_class                 => ManageIQ::Providers::InfraManager::OrchestrationStack,
        :inventory_object_attributes => [
          :type,
          :name,
          :description,
          :status,
          :status_reason,
          :parent,
          :orchestration_template,
          :cloud_tenant
        ]
      }
      super(attributes.merge!(extra_attributes))
    end

    def orchestration_templates(extra_attributes = {})
      attributes = {
        :inventory_object_attributes => [
          :type,
          :name,
          :description,
          :content,
          :orderable
        ]
      }
      super(attributes.merge!(extra_attributes))
    end

    def hosts(extra_attributes = {})
      attributes = {
        :model_class                 => ManageIQ::Providers::Openstack::InfraManager::Host,
        :association                 => :hosts,
        :inventory_object_attributes => [
          :type,
          :uid_ems,
          :operating_system,
          :maintenance,
          :maintenance_reason,
          :service_tag,
          :vmm_vendor,
          :vmm_version,
          :ems_cluster,
          :ipaddress,
          :hostname,
          :mac_address,
          :ipmi_address,
          :hypervisor_hostname,
          :power_state,
          :connection_state,
          :availability_zone_id
        ]
      }
      attributes.merge!(extra_attributes)
    end
  end
end
