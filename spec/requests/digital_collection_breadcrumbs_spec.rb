# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Digital Collection breadcrumbs', type: :request, singletenant: true, clean_repo: true do
  include Devise::Test::IntegrationHelpers

  let(:doc) { Nokogiri::HTML(response.body) }

  def indexed_open(resource)
    saved = Hyrax.persister.save(resource:)
    Hyrax::VisibilityWriter.new(resource: saved).assign_access_for(visibility: 'open')
    saved.permission_manager.acl.save
    Hyrax.index_adapter.save(resource: saved)
    saved
  end

  let(:collection) do
    indexed_open(DigitalCollection.new(title: ['Harbor Photographs'],
                                       collection_type_gid: Hyrax::CollectionType.find_or_create_default_collection_type.to_global_id.to_s))
      .tap { |saved| Hyrax::PermissionTemplate.find_or_create_by!(source_id: saved.id.to_s) }
  end

  before do
    Hyrax::Group.create(name: 'admin')
    sign_in FactoryBot.create(:admin)
    allow_any_instance_of(ApplicationController).to receive(:home_page_theme).and_return('digital_collection')
    allow_any_instance_of(ApplicationController).to receive(:show_page_theme).and_return('digital_collection_show')
  end

  it 'puts the collection page trail on the banner, above the badges' do
    get "/collections/#{collection.id}"

    plate = doc.at_css('section.dc-collection-banner .dc-collection-plate')
    expect(plate.element_children.first.matches?('nav.dc-collection-breadcrumbs')).to be(true)
    expect(plate.css('nav.dc-collection-breadcrumbs li').map { |li| li.text.strip }).to eq(['Home', 'Harbor Photographs'])
  end

  it "keeps a work page's trail in the gray bar" do
    work = indexed_open(Book.new(title: ['The Harbor'], member_of_collection_ids: [collection.id]))

    get "/concern/books/#{work.id}"

    expect(doc.css('.dc-secondary-header nav.dc-breadcrumbs li').map { |li| li.text.strip }).to eq(['Home', 'Harbor Photographs', 'The Harbor'])
    expect(doc.at_css('nav.dc-collection-breadcrumbs')).to be_nil
  end
end
