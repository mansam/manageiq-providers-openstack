require_relative '../openstack_stubs'

describe ManageIQ::Providers::Openstack::CloudManager::Refresher do
  include OpenstackStubs

  describe "refresh" do
    before do
      @ems = FactoryGirl.create(:ems_openstack_with_authentication)
      EvmSpecHelper.local_miq_server(:zone => Zone.seed)
    end

    it "refreshes twice, first creating all entities and then updating all entities" do
      @data_scaling = 1
      2.times do
        setup_mocked_collector
        assert_do_not_delete
        refresh_spec
      end
    end

    it "refreshes twice, first creating all entities and then updating existing and deleting missing entities" do
      @data_scaling         = 2
      @disconnect_inv_count = 0
      2.times do
        setup_mocked_collector
        refresh_spec
        @data_scaling         -= 1
        @disconnect_inv_count += 1
      end
    end

    it "refreshes twice, first creating all entities and then updating existing and creating new entities" do
      @data_scaling = 1
      2.times do
        setup_mocked_collector
        assert_do_not_delete
        refresh_spec
        @data_scaling += 1
      end
    end

    it "refreshes twice, first creating all entities and then deleting all entities from the db" do
      @data_scaling = 1
      2.times do
        setup_mocked_collector
        refresh_spec do
          VmOrTemplate.all.map(&:destroy) if @data_scaling == 0
        end
        @data_scaling -= 1
      end
    end

    def refresh_spec
      @ems.reload
      # with_openstack_stubbed(stub_responses) do
      EmsRefresh.refresh(@ems)
      # end
      @ems.reload

      yield if block_given?

      assert_table_counts
      assert_ems
    end

    def expected_table_counts(disconnect = nil)
      disconnect ||= disconnect_inv_factor

      vm_count     = test_counts(@data_scaling)[:vms_count]
      image_count  = test_counts(@data_scaling)[:miq_templates_count]

      # Disconnect_inv count, when these objects are not found in the API, they are not deleted in DB, but just marked
      # as disconnected
      vm_count_plus_disconnect_inv    = vm_count + test_counts(disconnect)[:vms_count]
      image_count_plus_disconnect_inv = image_count + test_counts(disconnect)[:miq_templates_count]
      {
        :auth_private_key              => test_counts(@data_scaling)[:key_pairs_count],
        :ext_management_system         => 4,
        :flavor                        => test_counts(@data_scaling)[:flavors_count],
        :host_aggregate                => test_counts(@data_scaling)[:host_aggregates_count],
        :availability_zone             => 2,
        :vm_or_template                => vm_count_plus_disconnect_inv + image_count_plus_disconnect_inv,
        :vm                            => vm_count_plus_disconnect_inv,
        :miq_template                  => image_count_plus_disconnect_inv,
        :disk                          => vm_count_plus_disconnect_inv,
        :hardware                      => vm_count_plus_disconnect_inv + image_count_plus_disconnect_inv,
        :network                       => vm_count_plus_disconnect_inv * 2,
        :orchestration_template        => test_counts([@data_scaling, 1 + disconnect].max)[:orchestration_stacks_count],
        :orchestration_stack           => test_counts(@data_scaling)[:orchestration_stacks_count],
        :orchestration_stack_parameter => test_counts(@data_scaling)[:orchestration_stacks_count],
        :orchestration_stack_output    => test_counts(@data_scaling)[:orchestration_stacks_count] + test_counts[:vnfs_count],
        :orchestration_stack_resource  => test_counts(@data_scaling)[:orchestration_stacks_count],
      }
    end

    def assert_table_counts
      actual = {
        :auth_private_key              => AuthPrivateKey.count,
        :ext_management_system         => ExtManagementSystem.count,
        :flavor                        => Flavor.count,
        :host_aggregate                => HostAggregate.count,
        :availability_zone             => AvailabilityZone.count,
        :vm_or_template                => VmOrTemplate.count,
        :vm                            => Vm.count,
        :miq_template                  => MiqTemplate.count,
        :disk                          => Disk.count,
        :hardware                      => Hardware.count,
        :network                       => Network.count,
        :orchestration_template        => OrchestrationTemplate.count,
        :orchestration_stack           => OrchestrationStack.count,
        :orchestration_stack_parameter => OrchestrationStackParameter.count,
        :orchestration_stack_output    => OrchestrationStackOutput.count,
        :orchestration_stack_resource  => OrchestrationStackResource.count,
      }
      expect(actual).to eq expected_table_counts
    end

    def setup_mocked_collector
      allow_any_instance_of(ManageIQ::Providers::Openstack::Inventory::Collector::CloudManager).to receive(:image_service).and_return(double(:name => "not-glance"))
      allow_any_instance_of(ManageIQ::Providers::Openstack::Inventory::Collector::CloudManager).to receive(:availability_zones).and_return(mocked_availability_zones)
      allow_any_instance_of(ManageIQ::Providers::Openstack::Inventory::Collector::CloudManager).to receive(:cloud_services).and_return(mocked_cloud_services)
      allow_any_instance_of(ManageIQ::Providers::Openstack::Inventory::Collector::CloudManager).to receive(:flavors).and_return(mocked_flavors)
      allow_any_instance_of(ManageIQ::Providers::Openstack::Inventory::Collector::CloudManager).to receive(:host_aggregates).and_return(mocked_host_aggregates)
      allow_any_instance_of(ManageIQ::Providers::Openstack::Inventory::Collector::CloudManager).to receive(:images).and_return(mocked_miq_templates)
      allow_any_instance_of(ManageIQ::Providers::Openstack::Inventory::Collector::CloudManager).to receive(:key_pairs).and_return(mocked_key_pairs)
      allow_any_instance_of(ManageIQ::Providers::Openstack::Inventory::Collector::CloudManager).to receive(:quotas).and_return(mocked_quotas)
      allow_any_instance_of(ManageIQ::Providers::Openstack::Inventory::Collector::CloudManager).to receive(:quotas).and_return([])
      allow_any_instance_of(ManageIQ::Providers::Openstack::Inventory::Collector::CloudManager).to receive(:quotas).and_return([])
      allow_any_instance_of(ManageIQ::Providers::Openstack::Inventory::Collector::CloudManager).to receive(:orchestration_stacks).and_return(mocked_orchestration_stacks)
      allow_any_instance_of(ManageIQ::Providers::Openstack::Inventory::Collector::CloudManager).to receive(:vms).and_return(mocked_vms)
      allow_any_instance_of(ManageIQ::Providers::Openstack::Inventory::Collector::CloudManager).to receive(:vnfs).and_return(mocked_vnfs)
      allow_any_instance_of(ManageIQ::Providers::Openstack::Inventory::Collector::CloudManager).to receive(:vnfds).and_return(mocked_vnfds)
      allow_any_instance_of(ManageIQ::Providers::Openstack::Inventory::Collector::CloudManager).to receive(:tenants).and_return(mocked_cloud_tenants)
      allow_any_instance_of(ManageIQ::Providers::Openstack::Inventory::Collector::CloudManager).to receive(:private_flavor).and_return(nil)
      allow_any_instance_of(ManageIQ::Providers::Openstack::Inventory::Collector::CloudManager).to receive(:volume_templates).and_return(mocked_volume_templates)
    end

    def assert_ems
      ems = @ems

      # The disconnected entities should not be associated to ems, so we get counts as expected_table_counts(0)
      expect(ems.flavors.size).to eql(expected_table_counts[:flavor])
      expect(ems.availability_zones.size).to eql(expected_table_counts[:availability_zone])
      expect(ems.vms_and_templates.size).to eql(expected_table_counts(0)[:vm_or_template])
      expect(ems.miq_templates.size).to eq(expected_table_counts(0)[:miq_template])
      expect(ems.orchestration_stacks.size).to eql(expected_table_counts[:orchestration_stack])
    end
  end
end
