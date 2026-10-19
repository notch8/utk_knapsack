# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Hyrax::CitationsBehaviors::NameBehaviorDecorator do
  subject(:helper_object) { Class.new { include Hyrax::CitationsBehaviors::NameBehavior }.new }

  it 'cites the names in creators, once each' do
    work = double('work', creators: [{ 'name' => 'Bernstein, Leonard', 'role' => 'Compiler' }, { 'name' => 'Bernstein, Leonard', 'role' => 'Editor' }],
                          creator: [])

    expect(helper_object.all_authors(work)).to eq(['Bernstein, Leonard'])
  end

  it 'passes each name through the block the citation formatters give it' do
    work = double('work', creators: [{ 'name' => 'Ada Lovelace' }], creator: [])

    expect(helper_object.all_authors(work, &:upcase)).to eq(['ADA LOVELACE'])
  end

  it 'falls back to the plain creator field when a work has no creators' do
    work = double('work', creators: [], creator: ['Hudson River Museum'])

    expect(helper_object.all_authors(work)).to eq(['Hudson River Museum'])
  end
end
