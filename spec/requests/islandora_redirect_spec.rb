# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Legacy Islandora URLs', type: :request, singletenant: true do
  let(:docs) do
    [
      { id: 'i566-collection', has_model_ssim: ['DigitalCollection'], primary_identifier_sim: ['collections:i566'] },
      { id: 'i566-book', has_model_ssim: ['Book'], primary_identifier_sim: ['i566:1'] },
      { id: 'i566-page', has_model_ssim: ['FileSet'], primary_identifier_sim: ['i566:2'] },
      { id: 'i566-private', has_model_ssim: ['Book'], primary_identifier_sim: ['i566:6'], read_access_group_ssim: [] },
      { id: 'i566-dotted', has_model_ssim: ['Pdf'], primary_identifier_sim: ['i566.ead:4.1'] }
    ]
  end

  before { Hyrax::SolrService.add(docs.map { |doc| { read_access_group_ssim: ['public'] }.merge(doc) }, commit: true) }
  after { Hyrax::SolrService.delete_by_query('id:i566-*', commit: true) }

  it 'permanently redirects a collection PID to the collection' do
    get '/collections/islandora/object/collections:i566'

    expect(response).to have_http_status(:moved_permanently)
    expect(URI(response.location).path).to eq '/collections/i566-collection'
  end

  it 'accepts an encoded colon' do
    get '/collections/islandora/object/collections%3Ai566'

    expect(URI(response.location).path).to eq '/collections/i566-collection'
  end

  it 'redirects a work PID to the work' do
    get '/collections/islandora/object/i566:1'

    expect(URI(response.location).path).to eq '/concern/books/i566-book'
  end

  it 'redirects a page PID to its file set' do
    get '/collections/islandora/object/i566:2'

    expect(URI(response.location).path).to eq '/concern/file_sets/i566-page'
  end

  it 'ignores the rest of the path, the query and the missing collections prefix' do
    get '/islandora/object/i566%3A1/datastream/OBJ/view.jpg?sort=score%20desc'

    expect(URI(response.location).path).to eq '/concern/books/i566-book'
    expect(response.location).not_to include 'sort'
  end

  it 'keeps dots in the PID' do
    get '/collections/islandora/object/i566.ead:4.1/datastream/OBJ/view.jpg'

    expect(URI(response.location).path).to eq '/concern/pdfs/i566-dotted'
  end

  it 'sends the Islandora collections root home without a warning' do
    get '/collections/islandora/object/digital%3Acollections'

    expect(response).to have_http_status(:moved_permanently)
    expect(URI(response.location).path).to eq '/'
    expect(flash[:alert]).to be_nil
  end

  it 'sends the bare collections path home' do
    get '/collections/'

    expect(response).to have_http_status(:moved_permanently)
    expect(URI(response.location).path).to eq '/'
  end

  it 'sends an unknown PID home with a warning' do
    get '/collections/islandora/object/nope:1'

    expect(URI(response.location).path).to eq '/'
    expect(flash[:alert]).to eq 'We could not find nope:1.'
  end

  it 'treats a private record as not found' do
    get '/collections/islandora/object/i566:6'

    expect(URI(response.location).path).to eq '/'
    expect(flash[:alert]).to eq 'We could not find i566:6.'
  end

  it 'escapes the PID in the warning' do
    get '/collections/islandora/object/%3Ca%20href=x%3Ehi%3C%2Fa%3E'

    expect(flash[:alert]).to eq 'We could not find &lt;a href=x&gt;hi&lt;/a&gt;.'
  end

  it 'escapes the PID in the Solr query' do
    get '/collections/islandora/object/*'

    expect(URI(response.location).path).to eq '/'
  end
end
