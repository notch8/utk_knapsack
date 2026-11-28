# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Hyku::ThumbnailPresenterDecorator, type: :helper do
  let(:path) { '/downloads/w1?file=thumbnail' }
  let(:account) do
    Account.new(name: 'dc', cname: 'digital.example.edu').tap { |a| a.domain_names.build(cname: 'dc.old.example.com') }
  end

  def url_for_cname(cname)
    doc = SolrDocument.new('id' => 'w1', 'has_model_ssim' => ['StillImage'],
                           'thumbnail_path_ss' => path, 'account_cname_tesim' => [cname])
    helper.document_presenter(doc).thumbnail.url
  end

  before do
    allow(Site).to receive(:account).and_return(account)
    without_partial_double_verification do
      allow(helper).to receive(:blacklight_config).and_return(CatalogController.blacklight_config)
      allow(helper).to receive(:document_index_view_type).and_return(:list)
      allow(helper).to receive(:current_account).and_return(account)
    end
  end

  it "keeps a thumbnail indexed under the tenant's older domain relative" do
    expect(url_for_cname('dc.old.example.com')).to eq path
  end

  it "prefixes another tenant's thumbnail with its cname" do
    expect(url_for_cname('other.example.org')).to eq "http://other.example.org#{path}"
  end
end
