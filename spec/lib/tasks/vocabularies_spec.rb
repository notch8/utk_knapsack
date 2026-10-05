# frozen_string_literal: true

require 'rails_helper'
require 'rake'

Rake.application.rake_require('tasks/vocabularies', [HykuKnapsack::Engine.root.join('lib').to_s]) unless
  defined?(VocabularyReload)

RSpec.describe VocabularyReload do
  subject(:reload) { described_class.new(file: file.path, dry_run:) }

  let(:dry_run) { false }
  let(:account) { instance_double(Account, cname: 'test.example.com') }
  let(:authority) { Qa::LocalAuthority.create!(name: 'probe_types') }

  let(:file) do
    Tempfile.new(['probe_types', '.yml']).tap do |f|
      f.write(<<~YAML)
        description: From somewhere authoritative.
        terms:
          - id: http://example.com/a
            term: Alpha
          - id: http://example.com/b
            term: Beta
      YAML
      f.flush
    end
  end

  before do
    allow(AccountElevator).to receive(:switch!)
    authority
  end

  after { file.unlink }

  def entries
    authority.reload.local_authority_entries
  end

  it 'reads the terms the yml declares' do
    expect(reload.terms.map { |term| term['id'] }).to eq %w[http://example.com/a http://example.com/b]
  end

  it 'adds the terms the yml declares' do
    expect(reload.call(account, 'probe_types')).to include('2 added')
    expect(entries.pluck(:uri)).to match_array %w[http://example.com/a http://example.com/b]
  end

  # Numbered from one on every run, so a term does not inherit the position of whatever
  # the tenant happened to hold before.
  it 'numbers the terms in the order the yml lists them' do
    reload.call(account, 'probe_types')
    expect(entries.order(:position).pluck(:position, :uri))
      .to eq [[1, 'http://example.com/a'], [2, 'http://example.com/b']]
  end

  # The rows live in the tenant's schema, so a run that skipped the switch would rebuild
  # whichever tenant happened to be current, once per account.
  it 'switches to the tenant before touching its rows' do
    expect(AccountElevator).to receive(:switch!).with('test.example.com')

    reload.call(account, 'probe_types')
  end

  it 'reports a tenant that does not have the vocabulary, without creating one' do
    expect(reload.call(account, 'absent_vocabulary')).to include('no absent_vocabulary vocabulary')
    expect(Qa::LocalAuthority.exists?(name: 'absent_vocabulary')).to be false
  end

  context 'with a term the yml no longer lists' do
    before { authority.local_authority_entries.create!(uri: 'Legacy', label: 'Legacy', position: 9) }

    it 'removes it' do
      expect(reload.call(account, 'probe_types')).to include('1 removed')
      expect(entries.pluck(:uri)).not_to include 'Legacy'
    end

    context 'when asked for a dry run' do
      let(:dry_run) { true }

      it 'reports the removal without making it' do
        expect(reload.call(account, 'probe_types')).to include('would apply', '1 removed')
        expect(entries.pluck(:uri)).to include 'Legacy'
      end
    end
  end

  # LocalVocabularyService fills a description only while it is blank, so a tenant seeded
  # before the wording changed would otherwise keep the old one forever.
  it 'updates a description the tenant was seeded with' do
    authority.update!(description: 'Seeded wording')
    reload.call(account, 'probe_types')

    expect(authority.reload.description).to eq 'From somewhere authoritative.'
  end

  it 'converges on the yml however many times it runs' do
    reload.call(account, 'probe_types')
    reload.call(account, 'probe_types')

    expect(entries.pluck(:uri)).to match_array %w[http://example.com/a http://example.com/b]
  end
end
