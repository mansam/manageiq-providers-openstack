class ManageIQ::Providers::Openstack::Inventory::Persister::CinderManager < ManageIQ::Providers::Openstack::Inventory::Persister
  def initialize_inventory_collections
    add_inventory_collections(storage,
                              %i(
                                cloud_volumes
                                cloud_volume_snapshots
                                cloud_volume_backups
                                cloud_volume_types
                              ),
                              :builder_params => {:ext_management_system => manager})

    add_inventory_collections(cloud,
                              %i(
                                vms
                                availability_zones
                                hardwares
                                cloud_tenants
                              ),
                              :parent   => manager.parent_manager,
                              :strategy => :local_db_cache_all)

    add_inventory_collections(cloud,
                              %i(
                                disks
                              ),
                              :parent   => manager.parent_manager,
                              :complete => false)
  end
end
