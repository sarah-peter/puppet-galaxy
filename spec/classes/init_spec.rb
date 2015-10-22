require 'spec_helper'
describe 'galaxy' do

  context 'with defaults for all parameters' do
    it { should contain_class('galaxy') }
  end
end
