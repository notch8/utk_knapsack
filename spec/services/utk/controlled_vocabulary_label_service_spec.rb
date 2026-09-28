# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Utk::ControlledVocabularyLabelService do
  subject(:service) { described_class.new }

  let(:uri) { 'http://id.loc.gov/authorities/subjects/sh85129277' }

  before do
    allow(UriLabelResolver).to receive(:label_for).with(uri).and_return('Student newspapers')
  end

  describe '#resolvable?' do
    # Hyrax asks this before it writes a label field and again before the catalog reads
    # one back, so answering false for a remote authority would leave the catalog
    # rendering a raw URI for a label the index already holds.
    it 'answers for a remote authority Hyku declines' do
      expect(Hyku::ControlledVocabularyLabelService.new.resolvable?('lcsh')).to be false
      expect(service.resolvable?('lcsh')).to be true
    end

    it 'does not answer for a property that cites no vocabulary' do
      expect(service.resolvable?('')).to be false
      expect(service.resolvable?(nil)).to be false
    end
  end

  describe '#labels_for' do
    it 'resolves a URI the local vocabularies do not hold' do
      expect(service.labels_for('lcsh', [uri])).to eq ['Student newspapers']
    end

    it 'leaves a value that is not a URI' do
      expect(UriLabelResolver).not_to receive(:label_for)

      expect(service.labels_for('lcsh', ['just a string'])).to eq ['just a string']
    end

    # `label_for` answers with the URI itself, sometimes annotated, when it cannot
    # resolve one. Showing that to a reader is worse than showing the id.
    it 'keeps the stored id when resolution fails' do
      allow(UriLabelResolver).to receive(:label_for).with(uri).and_return("#{uri} (No label found)")

      expect(service.labels_for('lcsh', [uri])).to eq [uri]
    end

    it 'keeps the stored id when the resolver raises' do
      allow(UriLabelResolver).to receive(:label_for).with(uri).and_raise(StandardError, 'boom')

      expect(service.labels_for('lcsh', [uri])).to eq [uri]
    end

    # Hyrax pairs values to labels by index, so a value nothing resolves has to hold its
    # place rather than being dropped.
    it 'answers positionally' do
      expect(service.labels_for('lcsh', ['plain', uri])).to eq ['plain', 'Student newspapers']
    end

    context 'with a vocabulary held locally' do
      let(:authority) { Qa::LocalAuthority.create!(name: 'probe_vocab') }

      before do
        authority.local_authority_entries.create!(uri: 'http://example.com/a', label: 'Alpha', position: 1)
      end

      it 'takes the local term rather than the cache' do
        expect(UriLabelResolver).not_to receive(:label_for)

        expect(service.labels_for('probe_vocab', ['http://example.com/a'])).to eq ['Alpha']
      end

      # A vocabulary keyed by URI, which is how resource_types and rights_statements are
      # shaped, holds some of a property's values and not others. Resolving per call
      # rather than per value would let the held one suppress the rest.
      it 'still resolves a value the vocabulary does not hold' do
        expect(service.labels_for('probe_vocab', ['http://example.com/a', uri]))
          .to eq ['Alpha', 'Student newspapers']
      end
    end
  end
end
