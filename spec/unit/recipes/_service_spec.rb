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
      ChefSpec::Runner.new(node_attributes) do |node|
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
      ChefSpec::Runner.new(node_attributes) do |node|
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

  context 'with gossip_encryption turned ON' do
    context 'with key exists in the databag' do
      let(:chef_run) do
        ChefSpec::Runner.new(node_attributes) do |node|
          node.set['consul']['encrypt_enabled'] = true
        end.converge(described_recipe)
      end
      before do
        allow(Chef::EncryptedDataBagItem).to receive(:load)
          .with('consul', 'encrypt')
          .and_return({'encrypt' => 'consul_secret'})
      end
      it do
        expect(chef_run).to create_file('/etc/consul.d/default.json')
          .with_content(/consul_secret/)
      end
    end
    context 'with key doesn\'t exist in the databag' do
      context 'databag doesn\'t exists' do
        let(:chef_run) do
          ChefSpec::Runner.new(node_attributes) do |node|
            node.set['consul']['encrypt_enabled'] = true
            node.set['consul']['encrypt'] = "consul_secret_node_attr"
          end.converge(described_recipe)
        end
        before do
          allow(Chef::EncryptedDataBagItem).to receive(:load)
            .with('consul', 'encrypt')
            .and_raise(Net::HTTPServerException.new("Consul databag not found", Net::HTTPResponse.new('1.1', '404', '')))
        end
        it do
          expect(chef_run).to create_file('/etc/consul.d/default.json')
            .with_content(/consul_secret_node_attr/)
        end
      end
      context 'encrypt is empty in the node attribute' do
        let(:chef_run) do
          ChefSpec::Runner.new(node_attributes) do |node|
            node.set['consul']['encrypt_enabled'] = true
            node.set['consul']['encrypt'] = ''
          end.converge(described_recipe)
        end
        before do
          allow(Chef::EncryptedDataBagItem).to receive(:load)
            .with('consul', 'encrypt')
            .and_return({'encrypt' => nil})
        end
        it do
          expect{chef_run}.to raise_error(Exception, /Consul encrypt key is empty/)
        end
      end
    end
  end
  context 'with tls enabled' do
    context 'when node key file and ca_cert is unique and exists in databag, verify* is true and ca_file doesn\'t exist in databag' do
      let(:chef_run) do
        ChefSpec::Runner.new(node_attributes) do |node|
          node.set['consul']['verify_incoming'] = true
          node.set['consul']['verify_outgoing'] = true
          node.set['consul']['ca_cert'] = 'begin_consul_node_ca_file_end'
          node.automatic['fqdn'] = 'foo_host'
        end.converge(described_recipe)
      end
      before do
        allow(Chef::EncryptedDataBagItem).to receive(:load)
          .with('consul', 'encrypt')
          .and_return({'key_file_foo_host' => 'begin_consul_db_key_file_end' \
            , 'cert_file_foo_host' => 'begin_consul_db_cert_file_end'})
      end
      it do
        expect(chef_run).to create_file('/etc/consul.d/ca.pem')
          .with_content(/begin_consul_node_ca_file_end/)
        expect(chef_run).to create_file('/etc/consul.d/key.pem')
          .with_content(/consul_db_key_file_end/)
        expect(chef_run).to create_file('/etc/consul.d/cert.pem')
          .with_content(/begin_consul_db_cert_file_end/)
        expect(chef_run).to create_file('/etc/consul.d/default.json')
          .with_content(/verify_incoming": true/)
        expect(chef_run).to create_file('/etc/consul.d/default.json')
          .with_content(/verify_outgoing": true/)
        expect(chef_run).to create_file('/etc/consul.d/default.json')
          .with_content(/key.pem/)
        expect(chef_run).to create_file('/etc/consul.d/default.json')
          .with_content(/ca.pem/)
      end
    end
    context 'when node key, cert, and ca is nil, and verify incoming true' do
      let(:chef_run) do
        ChefSpec::Runner.new(node_attributes) do |node|
          node.set['consul']['verify_incoming'] = true
        end.converge(described_recipe)
      end
      before do
        allow(Chef::EncryptedDataBagItem).to receive(:load)
          .with('consul', 'encrypt')
          .and_return({})
      end
      it do
        expect(chef_run).not_to create_file('/etc/consul.d/ca.pem')
        expect(chef_run).not_to create_file('/etc/consul.d/key.pem')
        expect(chef_run).not_to create_file('/etc/consul.d/cert.pem')
        expect(chef_run).to create_file('/etc/consul.d/default.json')
          .with_content(/verify_incoming": true/)
        expect(chef_run).to create_file('/etc/consul.d/default.json')
          .with_content(/verify_outgoing": false/)
      end
    end
    context 'when key_file, and cert exists as the node\'s attributes, and verify_outgoing true' do
      let(:chef_run) do
        ChefSpec::Runner.new(node_attributes) do |node|
          node.set['consul']['verify_outgoing'] = true
          node.set['consul']['key_file'] = 'begin_consul_node_key_file_end'
          node.set['consul']['cert_file'] = 'begin_consul_node_cert_file_end'
        end.converge(described_recipe)
      end
      before do
        allow(Chef::EncryptedDataBagItem).to receive(:load)
          .with('consul', 'encrypt')
          .and_raise(Net::HTTPServerException.new("Consul databag not found", Net::HTTPResponse.new('1.1', '404', '')))
      end
      it do
        expect(chef_run).not_to create_file('/etc/consul.d/ca.pem')
        expect(chef_run).to create_file('/etc/consul.d/key.pem')
          .with_content(/begin_consul_node_key_file_end/)
        expect(chef_run).to create_file('/etc/consul.d/cert.pem')
          .with_content(/begin_consul_node_cert_file_end/)
        expect(chef_run).to create_file('/etc/consul.d/default.json')
          .with_content(/verify_incoming": false/)
        expect(chef_run).to create_file('/etc/consul.d/default.json')
          .with_content(/verify_outgoing": true/)
      end
    end
  end
end
