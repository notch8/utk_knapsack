# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HykuKnapsack::IndexedCname do
  let(:account) do
    Account.new(name: 'dc', cname: 'digital.example.edu').tap { |a| a.domain_names.build(cname: 'dc.old.example.com') }
  end

  before { allow(Site).to receive(:account).and_return(account) }

  it "maps an older domain of the current tenant to its current cname" do
    expect(described_class.current('DC.old.example.com')).to eq 'digital.example.edu'
  end

  it "leaves another tenant's cname alone" do
    expect(described_class.current('other.example.org')).to eq 'other.example.org'
  end

  it 'leaves a blank cname alone' do
    expect(described_class.current(nil)).to be_nil
  end

  context 'without a current account' do
    let(:account) { nil }

    it 'leaves the cname alone' do
      expect(described_class.current('dc.old.example.com')).to eq 'dc.old.example.com'
    end
  end
end
