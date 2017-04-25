class ManageIQ::Providers::Openstack::Inventory::Persister::InfraManager < ManagerRefresh::Inventory::Persister
  def infra
    ManageIQ::Providers::Openstack::InventoryCollectionDefault::InfraManager
  end

  def initialize_inventory_collections
    add_inventory_collections(
      infra,
      %i(
        miq_templates
        orchestration_stacks
        hosts
        clusters
      ),
      :builder_params => {:ext_management_system => manager}
    )

    add_inventory_collections(
      infra,
      %i(
        hardwares
        disks
        networks
        orchestration_templates
        orchestration_stacks_resources
        orchestration_stacks_outputs
        orchestration_stacks_parameters
      )
    )

    add_inventory_collection(
      infra.orchestration_stack_ancestry(
        :dependency_attributes => {
          :orchestration_stacks => [collections[:orchestration_stacks]],
        }
      )
    )
  end
end
