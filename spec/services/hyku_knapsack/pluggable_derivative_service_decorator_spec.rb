# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HykuKnapsack::PluggableDerivativeServiceDecorator do
  let(:config) { double('iiif_print_config', derivative_service_plugins: [IiifPrint::TextExtractionDerivativeService]) }

  def plugins_for(rdf_type)
    file_set = FactoryBot.valkyrie_create(:hyrax_file_set, rdf_type: [rdf_type])
    original = Hyrax.persister.save(resource: Hyrax::FileMetadata.new(file_set_id: file_set.id, mime_type: 'image/png'))
    allow(IiifPrint).to receive(:parent_for).and_return(double('work', iiif_print_config: config))
    IiifPrint::PluggableDerivativeService.new(original).plugins
  end

  it 'gives a supplied thumbnail image only the default plugins' do
    expect(plugins_for('ThumbnailImage')).to eq [Hyrax::FileSetDerivativesService]
  end

  it 'keeps the work type plugins for an intermediate file' do
    expect(plugins_for('IntermediateFile')).to include IiifPrint::TextExtractionDerivativeService
  end
end
