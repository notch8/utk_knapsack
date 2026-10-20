# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Bulkrax::ValkyrieObjectFactoryFileSetDecorator do
  let(:user) { ::User.system_user }

  def build_factory(work, title)
    attributes = { 'title' => [title], 'parents' => [work.id.to_s], 'file' => [fixture_path.to_s] }
    Bulkrax::ValkyrieObjectFactory.new(attributes:,
                                       source_identifier_value: title,
                                       work_identifier: 'bulkrax_identifier',
                                       work_identifier_search_field: 'bulkrax_identifier_tesim',
                                       related_parents_parsed_mapping: 'parents',
                                       replace_files: false,
                                       user:,
                                       klass: Hyrax::FileSet,
                                       importer_run_id: nil,
                                       update_files: false).tap do |factory|
      allow(factory).to receive(:find_record) { [nil, Hyrax.query_service.find_by(id: work.id)] }
    end
  end

  def uploaded_file
    Hyrax::UploadedFile.create(file: File.open(fixture_path), user:)
  end

  let(:fixture_path) { HykuKnapsack::Engine.root.join('spec', 'fixtures', 'pdfs', 'portrait.pdf') }

  before do
    DatabaseCleaner.clean
    Hyrax::Group.find_or_create_by!(name: ::Ability.admin_group_name)
  end

  after do
    ids = Valkyrie::Persistence::Postgres::ORM::Resource.pluck(:id)
    Hyrax::SolrService.delete_by_query("{!terms f=id}#{ids.join(',')}") if ids.any?
    Hyrax::SolrService.commit
    DatabaseCleaner.clean_with(:deletion, except: %w[hyrax_flexible_schemas])
    DatabaseCleaner.start
  end

  it 'keeps both file sets when two are created for one work at once' do
    work = Hyrax.persister.save(resource: StillImage.new(title: ['parent'], depositor: user.user_key, provider: ['UTK'],
                                                         rights_statement: ['In Copyright'], primary_identifier: ['parent'],
                                                         has_work_type: ['StillImage']))
    arrived = Queue.new
    allow_any_instance_of(Bulkrax::ValkyrieObjectFactory).to receive(:perform_transaction_for).and_wrap_original do |original, **kwargs, &block|
      arrived << true
      deadline = 2.seconds.from_now
      sleep 0.05 until arrived.size > 1 || Time.current > deadline
      original.call(**kwargs, &block)
    end

    threads = %w[first second].map do |title|
      upload = uploaded_file
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ActiveRecord::Base.cache { build_factory(work, title).send(:create_file_set, uploaded_files: [upload.id]) }
        end
      end
    end
    sleep 0.05 while threads.any?(&:alive?)
    threads.each(&:join)

    members = Hyrax.query_service.find_members(resource: Hyrax.query_service.find_by(id: work.id)).to_a
    expect(members.map { |member| member.title.first }).to contain_exactly('first', 'second')
  end
end
