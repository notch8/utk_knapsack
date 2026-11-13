# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HykuKnapsack::LocalSeed::Records do
  subject(:seed) { described_class.new(dir:, io: StringIO.new) }

  let(:dir) { Pathname(Dir.mktmpdir) }
  let(:work_id) { SecureRandom.uuid }
  let(:collection_id) { SecureRandom.uuid }
  let(:file_set_id) { SecureRandom.uuid }
  let(:file_id) { SecureRandom.uuid }
  let(:prod_admin_set) { SecureRandom.uuid }

  def row(id, internal_resource, metadata)
    { id:, internal_resource:, lock_version: 0, created_at: '2026-10-29T10:36:03.802617Z',
      updated_at: '2026-10-29T10:36:03.802617Z', metadata: }
  end

  before do
    allow(Hyrax).to receive(:storage_adapter).and_return(Valkyrie::StorageAdapter.find(:test_disk))
    Hyrax::Group.find_or_create_by!(name: ::Ability.admin_group_name)
    records = [
      row(collection_id, 'DigitalCollection', title: ['Seeded collection'], schema_version: [99],
                                              collection_type_gid: ['gid://hyku/Hyrax::CollectionType/9999']),
      row(work_id, 'Pdf', title: ['Seeded work'], schema_version: [99], admin_set_id: [{ id: prod_admin_set }],
                          member_ids: [{ id: file_set_id }], member_of_collection_ids: [{ id: collection_id }]),
      row(file_set_id, 'Hyrax::FileSet', title: ['page.pdf'], schema_version: [99], file_ids: [{ id: file_id }]),
      row(file_id, 'Hyrax::FileMetadata', file_set_id: [{ id: file_set_id }], original_filename: ['page.pdf'],
                                          mime_type: ['application/pdf'], pcdm_use: [{ '@id' => Hyrax::FileMetadata::Use::ORIGINAL_FILE.to_s }],
                                          file_identifier: [{ id: 'shrine://prod/key' }])
    ]
    dir.join('records.json').write(records.to_json)
    dir.join('files').mkpath
    dir.join('files', file_id).write('%PDF-1.4 seeded bytes')
  end

  after { dir.rmtree }

  it 'keeps production ids and points prod-only references at this tenant' do
    seed.call

    work = Hyrax.query_service.find_by(id: work_id)
    expect(work.title).to eq(['Seeded work'])
    expect(work.member_of_collection_ids.map(&:to_s)).to eq([collection_id])
    expect(work.admin_set_id.to_s).to eq(Hyrax::AdminSetCreateService.find_or_create_default_admin_set.id.to_s)
    expect(work.schema_version.to_s).to eq(Hyrax::FlexibleSchema.order(:id).last.id.to_s)
    collection = Hyrax.query_service.find_by(id: collection_id)
    expect(collection.collection_type_gid.to_s).to eq(Hyrax::CollectionType.find_or_create_default_collection_type.to_global_id.to_s)
  end

  it 'gives each collection the permission template its show page needs, managed by the seeded admin' do
    User.find_or_create_by!(email: HykuKnapsack::LocalSeed::ADMIN_EMAIL) { |user| user.password = 'testing123' }
    seed.call

    expect(Hyrax::PermissionTemplate.find_by(source_id: collection_id).access_grants.map(&:agent_id))
      .to include(::Ability.admin_group_name, HykuKnapsack::LocalSeed::ADMIN_EMAIL)
  end

  it 'stores the original under this tenant and enqueues its derivatives' do
    expect { seed.call }.to have_enqueued_job(ValkyrieCreateDerivativesJob).with(file_set_id, file_id)

    file = Hyrax.custom_queries.find_file_metadata_by(id: file_id)
    expect(file.file_identifier.to_s).not_to start_with('shrine://prod')
    expect(Hyrax.storage_adapter.find_by(id: file.file_identifier).read).to eq('%PDF-1.4 seeded bytes')
  end

  it 'deposits each work in its admin set workflow' do
    seed.call

    work = Hyrax.query_service.find_by(id: work_id)
    expect(Sipity::Entity.find_by(proxy_for_global_id: Hyrax::GlobalID(work).to_s).workflow_state.name).to eq('deposited')
    expect(Hyrax::SolrService.query("id:#{work_id}", fl: 'workflow_state_name_ssim').first['workflow_state_name_ssim']).to eq(['deposited'])
  end

  it 'indexes what it seeds' do
    seed.call

    expect(Hyrax::SolrService.query("id:#{work_id}", fl: 'member_of_collection_ids_ssim').first['member_of_collection_ids_ssim']).to eq([collection_id])
  end

  it 'restores on a rerun the templates and index entries a failed run left out' do
    seed.call
    Hyrax::PermissionTemplate.find_by(source_id: collection_id).destroy!
    Hyrax::SolrService.delete(work_id)
    Hyrax::SolrService.commit

    described_class.new(dir:, io: StringIO.new).call

    expect(Hyrax::PermissionTemplate.exists?(source_id: collection_id)).to be(true)
    expect(Hyrax::SolrService.count("id:#{work_id}")).to eq(1)
  end

  it 'inserts nothing when queuing derivatives fails, so a rerun queues them' do
    allow(ValkyrieCreateDerivativesJob).to receive(:perform_later).and_raise(StandardError, 'queue down')
    expect { seed.call }.to raise_error('queue down')
    allow(ValkyrieCreateDerivativesJob).to receive(:perform_later).and_call_original

    expect { described_class.new(dir:, io: StringIO.new).call }.to have_enqueued_job(ValkyrieCreateDerivativesJob).with(file_set_id, file_id)
  end

  it 'has queued derivatives before a later step can fail' do
    allow(seed).to receive(:index).and_raise(StandardError, 'solr down')

    expect { seed.call }.to raise_error('solr down')
    expect(ValkyrieCreateDerivativesJob).to have_been_enqueued.with(file_set_id, file_id)
  end

  it 'neither stores nor derives anything a second time' do
    seed.call

    expect { described_class.new(dir:, io: StringIO.new).call }
      .not_to(change { Hyrax.custom_queries.find_file_metadata_by(id: file_id).file_identifier })
    expect(ValkyrieCreateDerivativesJob).to have_been_enqueued.once
  end
end
