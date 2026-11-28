# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SharedSearchHelperDecorator, type: :helper do
  let(:account) do
    Account.new(name: 'dc', cname: 'digital.example.edu').tap { |a| a.domain_names.build(cname: 'dc.old.example.com') }
  end

  def doc(cname)
    SolrDocument.new('id' => 'w1', 'has_model_ssim' => ['StillImage'], 'account_cname_tesim' => [cname])
  end

  before { allow(Site).to receive(:account).and_return(account) }

  it "links a work indexed under the tenant's older domain to its current cname" do
    expect(helper.generate_work_url(doc('dc.old.example.com'), helper.request))
      .to match(%r{\Ahttp://digital\.example\.edu(:\d+)?/concern/still_images/w1\z})
  end

  it "links another tenant's work to that tenant" do
    expect(helper.generate_work_url(doc('other.example.org'), helper.request))
      .to match(%r{\Ahttp://other\.example\.org(:\d+)?/concern/still_images/w1\z})
  end
end
