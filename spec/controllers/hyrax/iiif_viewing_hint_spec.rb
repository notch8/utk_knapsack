# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'IIIF viewing hint' do
  Hyrax.config.registered_curation_concern_types.each do |type|
    controller_class = "Hyrax::#{type.pluralize}Controller".constantize
    hint = %w[CompoundObject Audio Video].include?(type) ? nil : 'paged'

    it "gives #{type} the #{hint.inspect} viewing hint" do
      expect(controller_class.iiif_viewing_hint).to eq hint
    end

    [true, false].each do |ranges|
      it "builds #{type}'s manifest with the #{hint.inspect} viewing hint, IIIF ranges #{ranges ? 'on' : 'off'}" do
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
        expect(manifest.values_at('viewingHint', 'behavior').compact.flatten).to eq Array(hint)
      end
    end
  end
end
