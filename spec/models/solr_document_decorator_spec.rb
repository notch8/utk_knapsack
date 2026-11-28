# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SolrDocumentDecorator do
  let(:account) do
    Account.new(name: 'dc', cname: 'digital.example.edu').tap { |a| a.domain_names.build(cname: 'dc.old.example.com') }
  end

  def identifiers(cname)
    SolrDocument.new('id' => 'w1', 'has_model_ssim' => ['StillImage'], 'thumbnail_path_ss' => '/downloads/w1',
                     'account_cname_tesim' => [cname]).to_semantic_values[:identifier]
  end

  before { allow(Site).to receive(:account).and_return(account) }

  it "points identifiers indexed under the tenant's older domain at its current cname" do
    expect(identifiers('dc.old.example.com'))
      .to include('https://digital.example.edu/concern/still_images/w1', 'https://digital.example.edu/downloads/w1')
  end

  it "leaves another tenant's identifiers on that tenant" do
    expect(identifiers('other.example.org'))
      .to include('https://other.example.org/concern/still_images/w1', 'https://other.example.org/downloads/w1')
  end
end
