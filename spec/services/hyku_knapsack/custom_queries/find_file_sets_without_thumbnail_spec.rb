# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HykuKnapsack::CustomQueries::FindFileSetsWithoutThumbnail do
  def file_set_with(*uses)
    file_set = Hyrax.persister.save(resource: Hyrax::FileSet.new(title: ['probe']))
    ids = uses.map do |use|
      Hyrax.persister.save(resource: Hyrax::FileMetadata.new(file_set_id: file_set.id, pcdm_use: [use])).id
    end
    file_set.file_ids = ids
    Hyrax.persister.save(resource: file_set)
  end

  def store_file_ids_as_strings(file_set)
    sql = "UPDATE orm_resources SET metadata = jsonb_set(metadata, '{file_ids}', ?::jsonb) WHERE id = ?"
    ActiveRecord::Base.connection.execute(ActiveRecord::Base.sanitize_sql_array([sql, file_set.file_ids.map(&:to_s).to_json, file_set.id.to_s]))
  end

  def stored_shape_of(file_set)
    sql = "SELECT jsonb_typeof(metadata->'file_ids'->0) FROM orm_resources WHERE id = ?"
    ActiveRecord::Base.connection.select_value(ActiveRecord::Base.sanitize_sql_array([sql, file_set.id.to_s]))
  end

  let!(:bare) { file_set_with(Hyrax::FileMetadata::Use::ORIGINAL_FILE) }
  let!(:with_thumbnail) { file_set_with(Hyrax::FileMetadata::Use::ORIGINAL_FILE, Hyrax::FileMetadata::Use::THUMBNAIL_IMAGE) }
  let!(:empty) { Hyrax.persister.save(resource: Hyrax::FileSet.new(title: ['nothing attached'])) }

  it 'is registered on the query service' do
    expect(Hyrax.custom_queries).to respond_to(:find_file_sets_without_thumbnail)
  end

  it 'yields file sets that have no ThumbnailImage, as resources' do
    found = Hyrax.custom_queries.find_file_sets_without_thumbnail.to_a

    expect(found).to all(be_a(Hyrax::FileSet))
    expect(found.map { |f| f.id.to_s }).to include(bare.id.to_s, empty.id.to_s)
  end

  it 'yields a file set whose thumbnail row is not among its file_ids, as Hyrax cannot find that thumbnail' do
    detached = file_set_with(Hyrax::FileMetadata::Use::ORIGINAL_FILE, Hyrax::FileMetadata::Use::THUMBNAIL_IMAGE)
    detached.file_ids = detached.file_ids.first(1)
    Hyrax.persister.save(resource: detached)

    expect(Hyrax.custom_queries.find_file_sets_without_thumbnail.map { |f| f.id.to_s }).to include(detached.id.to_s)
  end

  it 'leaves out a file set whose file_ids are stored as bare strings, as most tenants have them' do
    store_file_ids_as_strings(with_thumbnail)

    expect(stored_shape_of(with_thumbnail)).to eq 'string'
    expect(Hyrax.custom_queries.find_file_sets_without_thumbnail.map { |f| f.id.to_s }).not_to include(with_thumbnail.id.to_s)
  end

  it 'leaves out a file set whose thumbnail metadata exists' do
    expect(Hyrax.custom_queries.find_file_sets_without_thumbnail.map { |f| f.id.to_s }).not_to include(with_thumbnail.id.to_s)
  end

  it 'leaves out works, which are not file sets' do
    work = Hyrax.persister.save(resource: Pdf.new(title: ['a work']))

    expect(Hyrax.custom_queries.find_file_sets_without_thumbnail.map { |f| f.id.to_s }).not_to include(work.id.to_s)
  end
end
