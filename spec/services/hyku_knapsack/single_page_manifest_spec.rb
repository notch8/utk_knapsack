# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HykuKnapsack::SinglePageManifest do
  describe 'Builder' do
    it "wraps Hyku's manifest decorators, which each stamp the viewingHint" do
      expect(Hyrax::ManifestBuilderService.ancestors.first).to eq described_class::Builder
    end

    it 'leaves the viewingHint out and keeps the rest of the manifest' do
      builder = Class.new { def manifest_for(presenter:) = { 'type' => 'Manifest', 'viewingHint' => 'paged', 'items' => [presenter] } }
      builder.prepend(described_class::Builder)

      expect(builder.new.manifest_for(presenter: 'canvas')).to eq('type' => 'Manifest', 'items' => ['canvas'])
    end

    it 'leaves the viewingHint out of a manifest built with IIIF ranges on' do
      allow(Flipflop).to receive(:iiif_ranges?).and_return(true)
      manifest = double(to_h: { 'type' => 'Manifest', 'items' => [] })
      service = Hyrax::ManifestBuilderService.new(iiif_manifest_factory: double(new: manifest))

      expect(service.manifest_for(presenter: double)).to eq('type' => 'Manifest', 'items' => [])
    end

    it 'leaves the viewingHint out of a manifest built with IIIF ranges off and keeps the label sanitizing' do
      allow(Flipflop).to receive(:iiif_ranges?).and_return(false)
      manifest = double(to_h: { 'type' => 'Manifest', 'items' => [{ 'id' => 'c1', 'label' => { 'none' => ['Page <script>x</script>1'] } }] })
      service = Hyrax::ManifestBuilderService.new(iiif_manifest_factory: double(new: manifest))
      presenter = double(object: double(solr_document: { 'descendent_member_ids_ssim' => [] }))

      expect(service.manifest_for(presenter:)).to eq('type' => 'Manifest', 'items' => [{ 'id' => 'c1', 'label' => { 'none' => ['Page 1'] } }])
    end
  end

  describe 'Presenter' do
    it "adds the layout to the manifest's version, so caches drop their paged copies" do
      presenter = Hyrax::IiifManifestPresenter.new(SolrDocument.new(id: 'w1', system_modified_dtsi: '2026-10-14T00:00:00Z'))

      expect(presenter.version).to end_with '2026-10-14T00:00:00Z|single-page'
    end
  end
end
