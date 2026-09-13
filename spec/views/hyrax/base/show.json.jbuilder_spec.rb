# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'hyrax/base/show.json.jbuilder', type: :view do
  let(:resource) { Book.new(title: ['Annual report, 1925'], member_ids: [Valkyrie::ID.new('m1'), Valkyrie::ID.new('m2')]) }
  let(:json) { JSON.parse(rendered) }

  before do
    assign(:curation_concern, resource)
    render template: 'hyrax/base/show', formats: [:json]
  end

  it 'reports the order the file manager just saved' do
    expect(json['member_ids'].map { |m| m['id'] }).to eq %w[m1 m2]
  end

  it 'reports the id as a string the save manager can read' do
    expect(json['id']).to eq resource.id.to_s
  end

  it 'carries a version key, which the save manager stores off the response' do
    expect(json).to have_key 'version'
  end

  it 'drops the bookkeeping attributes that are not part of the record' do
    expect(json.keys).not_to include('new_record', 'internal_resource')
  end

  it 'serializes a Valkyrie resource without converting it through Wings' do
    expect(Wings::ActiveFedoraConverter).not_to receive(:convert)

    render template: 'hyrax/base/show', formats: [:json]
  end
end
