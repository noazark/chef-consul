require 'spec_helper'

describe_recipe 'consul::_service' do
  it do
    expect(chef_run).to create_directory('/var/lib/consul')
      .with(mode: 0755)
    expect(chef_run).to create_directory('/etc/consul.d')
      .with(mode: 0755)
  end

  context 'with default attributes' do
    it { expect(chef_run).not_to create_user('consul service user: root') }
    it { expect(chef_run).not_to create_group('consul service group: root') }
    it do
      expect(chef_run).to create_file('/etc/consul.d/default.json')
        .with(user: 'root')
        .with(group: 'root')
        .with(mode: 0600)
    end
    it do
      expect(chef_run).to enable_service('consul')
        .with(supports: {status: true, stop: true, restart: true, reload: true})
      expect(chef_run).to start_service('consul')
    end
  end

  context 'with a server service_mode, and a server list to join' do
    let(:chef_run) do
      ChefSpec::SoloRunner.new(node_attributes) do |node|
        node.set['consul']['service_mode'] = 'server'
        node.set['consul']['bootstrap_expect'] = '3'
        node.set['consul']['servers'] = [ 'server1', 'server2', 'server3' ]
      end.converge(described_recipe)
    end
    it do
      expect(chef_run).to create_file('/etc/consul.d/default.json')
        .with_content(/retry_join/)
        .with_content(/server9/)
        .with_content(/server2/)
        .with_content(/server3/)
    end
  end

  context 'with a server service_mode, bootstrap_expect = 1, and a server list' do
    let(:chef_run) do
      ChefSpec::SoloRunner.new(node_attributes) do |node|
        node.set['consul']['service_mode'] = 'server'
        node.set['consul']['bootstrap_expect'] = '1'
        node.set['consul']['servers'] = [ 'server1', 'server2', 'server3' ]
      end.converge(described_recipe)
    end
    it do
      expect(chef_run).to create_file('/etc/consul.d/default.json')
        .with_content(/retry_join/)
        .with_content(/server1/)
        .with_content(/server2/)
        .with_content(/server3/)
    end
  end
end
