# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HykuKnapsack::AvTranscriptsListener do
  subject(:listener) { described_class.new }

  before { stub_request(:get, %r{\Ahttps?://pcdm\.org/}).to_return(status: 404) }

  def file_set(use, ingested: true)
    file_set = Hyrax.persister.save(resource: Hyrax::FileSet.new(rdf_type: ["http://pcdm.org/use##{use}"]))
    return file_set unless ingested

    file = Hyrax.persister.save(resource: Hyrax::FileMetadata.new(file_set_id: file_set.id,
                                                                  pcdm_use: [Hyrax::FileMetadata::Use::ORIGINAL_FILE]))
    file_set.file_ids = [file.id]
    Hyrax.persister.save(resource: file_set)
  end

  def work(model, *members)
    Hyrax.persister.save(resource: model.new(member_ids: members.map(&:id)))
  end

  def membership_updated(object)
    listener.on_object_membership_updated({ object: })
  end

  def transcript_ids_of(resource)
    Hyrax.query_service.find_by(id: resource.id).transcript_ids
  end

  def expect_no_save
    persister = Hyrax.persister
    allow(Hyrax).to receive(:persister).and_return(persister)
    expect(persister).not_to receive(:save)
  end

  let(:media) { file_set('IntermediateFile') }
  let(:english) { file_set('Transcript') }
  let(:spanish) { file_set('Transcript') }

  [Audio, Video].each do |model|
    it "points a #{model} work's media at every Transcript sibling" do
      membership_updated(work(model, media, english, spanish))

      expect(transcript_ids_of(media)).to contain_exactly(english.id.to_s, spanish.id.to_s)
      expect(transcript_ids_of(english)).to be_empty
    end
  end

  it 'links from a file set event through its parent work' do
    work(Video, media, english)

    membership_updated(media)

    expect(transcript_ids_of(media)).to eq [english.id.to_s]
  end

  it 'indexes the links it saves' do
    membership_updated(work(Video, media, english))

    expect(SolrDocument.find(media.id.to_s)['transcript_ids_ssim']).to eq [english.id.to_s]
  end

  it 'runs when Hyrax publishes the event' do
    Hyrax.publisher.publish('object.membership.updated', object: work(Video, media, english), user: nil)

    expect(transcript_ids_of(media)).to eq [english.id.to_s]
  end

  it 'leaves a file set its ingest has not saved files to yet' do
    uningested = file_set('IntermediateFile', ingested: false)

    membership_updated(work(Video, uningested, english))

    expect(transcript_ids_of(uningested)).to be_empty
  end

  it 'keeps a link set by hand to a VTT without a Transcript rdf_type' do
    hand_linked = file_set('IntermediateFile')
    media.transcript_ids = [hand_linked.id.to_s]
    Hyrax.persister.save(resource: media)

    membership_updated(work(Video, media, hand_linked, english))

    expect(transcript_ids_of(media)).to contain_exactly(hand_linked.id.to_s, english.id.to_s)
  end

  it 'saves nothing when hand links already include every transcript' do
    hand_linked = file_set('IntermediateFile', ingested: false)
    media.transcript_ids = [hand_linked.id.to_s, english.id.to_s]
    Hyrax.persister.save(resource: media)
    parent = work(Video, media, hand_linked, english)
    expect_no_save

    membership_updated(parent)
  end

  it 'leaves other work types alone' do
    membership_updated(work(Book, media, english))

    expect(transcript_ids_of(media)).to be_empty
  end

  it 'saves nothing when the work has no transcripts' do
    parent = work(Video, media)
    expect_no_save

    membership_updated(parent)
  end

  it 'saves nothing when the links are already in place' do
    parent = work(Video, media, english)
    membership_updated(parent)
    expect_no_save

    membership_updated(parent)
  end

  it 'skips file sets whose tenant profile lacks transcript_ids' do
    parent = work(Video, media, english)
    custom_queries = Hyrax.custom_queries
    allow(Hyrax).to receive(:custom_queries).and_return(custom_queries)
    allow(custom_queries).to receive(:find_child_file_sets).and_wrap_original do |original, **kwargs|
      original.call(**kwargs).map do |file_set|
        allow(file_set).to receive(:respond_to?).and_call_original
        allow(file_set).to receive(:respond_to?).with(:transcript_ids=).and_return(false)
        file_set
      end
    end
    expect_no_save

    membership_updated(parent)
  end

  it 'logs a failure instead of raising into the publisher' do
    parent = work(Video, media, english)
    allow(Hyrax.custom_queries).to receive(:find_child_file_sets).and_raise(StandardError, 'boom')
    allow(Hyrax.logger).to receive(:error)

    expect { membership_updated(parent) }.not_to raise_error
    expect(Hyrax.logger).to have_received(:error).with(/boom/)
  end
end
