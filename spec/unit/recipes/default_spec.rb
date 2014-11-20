require 'spec_helper'

describe_recipe 'consul::default' do
  it { expect(chef_run).to include_recipe('consul::_service') }
  it { expect(chef_run).to include_recipe('consul::install_binary') }
end
