# frozen_string_literal: true

RSpec.describe 'bundler.d/example.rb' do
  let(:gem_lines) { File.readlines(File.expand_path('../../bundler.d/example.rb', __dir__)).grep(/\A\s*(ensure_|override_)?gem\b/) }

  it 'pins every git-sourced gem to a ref, since hyrax-webapp/Gemfile.lock never locks them' do
    git_lines = gem_lines.grep(/\b(github|git):/)

    expect(git_lines).not_to be_empty
    expect(git_lines.grep_v(/\bref:/)).to eq([])
  end
end
