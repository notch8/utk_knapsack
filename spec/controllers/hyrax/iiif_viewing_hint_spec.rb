# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'IIIF viewing hint' do
  Hyrax.config.registered_curation_concern_types.each do |type|
    controller_class = "Hyrax::#{type.pluralize}Controller".constantize

    it "opens #{type} one page at a time" do
      expect(controller_class.iiif_viewing_hint).to be_nil
    end

    [true, false].each do |ranges|
      it "builds #{type}'s manifest without a viewing hint, IIIF ranges #{ranges ? 'on' : 'off'}" do
        allow(Flipflop).to receive(:iiif_ranges?).and_return(ranges)
        controller = controller_class.new
        controller.request = ActionDispatch::TestRequest.create
        controller.params = { id: 'w1' }
        allow(controller).to receive(:current_ability).and_return(Ability.new(nil))
        allow(controller).to receive(:search_result_document)
          .and_return(SolrDocument.new(id: 'w1', has_model_ssim: [type], title_tesim: ['A work'], system_modified_dtsi: '2026-10-15T00:00:00Z'))
        presenter = controller.send(:iiif_manifest_presenter)
        allow(presenter).to receive_messages(manifest_url: "http://test.host/concern/works/w1/manifest", homepage: [])

        manifest = Hyrax::ManifestBuilderService.new.manifest_for(presenter:)

        expect(manifest).to include('type' => 'Manifest')
        expect(manifest.keys).not_to include('viewingHint', 'behavior')
      end
    end
  end
end
