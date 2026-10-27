# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'UTK footer', type: :request, singletenant: true do
  let(:doc) { Nokogiri::HTML(response.body) }

  it 'renders on a digital_collection page other than the homepage' do
    allow_any_instance_of(ApplicationController).to receive(:home_page_theme).and_return('digital_collection')
    get '/about'

    expect(doc.css('footer.utk-footer').size).to eq(1)
  end

  it "leaves another theme's homepage with Hyku's footer" do
    allow_any_instance_of(ApplicationController).to receive(:home_page_theme).and_return('default_home')
    get '/'

    expect(doc.css('footer').size).to eq(1)
    expect(doc.css('footer.utk-footer')).to be_empty
  end
end
