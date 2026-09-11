# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Hyrax::Renderers::CompoundAttributeRendererDecorator do
  subject(:markup) { renderer.send(:entries_markup) }

  let(:renderer) do
    Hyrax::Renderers::CompoundAttributeRenderer.new(:creators, entries, subproperties:)
  end
  let(:subproperties) do
    { 'name' => { type: 'string' },
      'role' => { type: 'controlled', authority: 'creator_roles' } }
  end

  def entry_count(html)
    html.scan('hyrax-compound-entry').size
  end

  def labels(html)
    html.scan(%r{<span class="hyrax-compound-subproperty-label">(.*?)</span>}).flatten
  end

  def values(html)
    html.scan(%r{<span class="hyrax-compound-subproperty-value">(.*?)</span>}).flatten
  end

  context 'with a name and a role' do
    let(:entries) { [{ 'name' => 'Ives, Charles', 'role' => 'Composer' }] }

    it 'renders the pair on one line, the role labelling the name' do
      expect(entry_count(markup)).to eq 1
      expect(labels(markup)).to eq ['Composer:']
      expect(values(markup)).to eq ['Ives, Charles']
    end

    it 'does not emit a separate line per sub-property' do
      expect(markup).not_to include 'Name:'
      expect(markup).not_to include 'Role:'
    end
  end

  context 'with several entries' do
    let(:entries) do
      [{ 'name' => 'Ives, Charles', 'role' => 'Composer' },
       { 'name' => 'Bernstein, Leonard', 'role' => 'Musical Director' }]
    end

    it 'renders one row per entry, in the order given' do
      expect(entry_count(markup)).to eq 2
      expect(labels(markup)).to eq ['Composer:', 'Musical Director:']
      expect(values(markup)).to eq ['Ives, Charles', 'Bernstein, Leonard']
    end
  end

  context 'with a name but no role' do
    let(:entries) { [{ 'name' => 'Ives, Charles' }] }

    it 'renders the name alone, with no label' do
      expect(labels(markup)).to be_empty
      expect(values(markup)).to eq ['Ives, Charles']
    end
  end

  context 'with a name and a blank role' do
    let(:entries) { [{ 'name' => 'Ives, Charles', 'role' => '' }] }

    it 'renders the name alone' do
      expect(labels(markup)).to be_empty
      expect(values(markup)).to eq ['Ives, Charles']
    end
  end

  context 'when a role id has no matching authority term' do
    let(:entries) { [{ 'name' => 'Ives, Charles', 'role' => 'StageManager' }] }

    it 'renders the indexed value rather than resolving it through the authority' do
      expect(Hyrax::CompoundSubpropertyLabeler).not_to receive(:label_for)
      expect(labels(markup)).to eq ['StageManager:']
    end
  end

  context 'with markup in the stored values' do
    let(:entries) { [{ 'name' => '<script>alert(1)</script>', 'role' => '<b>Composer</b>' }] }

    it 'escapes both halves' do
      expect(markup).to include '&lt;script&gt;alert(1)&lt;/script&gt;'
      expect(markup).to include '&lt;b&gt;Composer&lt;/b&gt;:'
      expect(markup).not_to include '<script>'
    end
  end

  context 'with a compound that is not a name/role pair' do
    let(:subproperties) { { 'value' => { type: 'string' }, 'type' => { type: 'string' } } }
    let(:entries) { [{ 'value' => '1234', 'type' => 'ISBN' }] }

    it 'leaves upstream one-line-per-sub-property rendering alone' do
      expect(labels(markup)).to eq ['Value:', 'Type:']
      expect(values(markup)).to eq ['1234', 'ISBN']
    end
  end
end
