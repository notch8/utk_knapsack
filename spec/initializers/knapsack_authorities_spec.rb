# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable RSpec/DescribeClass
RSpec.describe 'config/initializers/knapsack_authorities.rb' do
  let(:knapsack_path) { HykuKnapsack::AUTHORITIES_PATH }
  let(:hyku_path) { HykuKnapsack::HYKU_AUTHORITIES_PATH }

  # A name only Hyku ships and one only the knapsack ships, so a run that found
  # just one of the two directories fails on content rather than on a count that
  # a future yml would shift.
  let(:hyku_only) { 'media_viewer' }
  let(:knapsack_only) { 'creator_roles' }

  def names_from(dir)
    Dir.chdir(dir) { Qa::Authorities::Local.names }
  end

  it 'searches the knapsack before Hyku, so a knapsack yml wins' do
    expect(Qa::Authorities::Local.subauthorities_path.first(2))
      .to eq([knapsack_path, hyku_path])
  end

  it 'finds both sets of authorities from the knapsack root' do
    expect(names_from(HykuKnapsack::Engine.root))
      .to include(hyku_only, knapsack_only)
  end

  # `config[:local_path]` is the relative string "config/authorities", so from
  # the knapsack root it resolves to the knapsack's own directory. The webapp is
  # the anchor because that is where the server runs and where the bug never
  # showed.
  it 'finds the same authorities whatever the working directory' do
    from_knapsack = names_from(HykuKnapsack::Engine.root)
    from_webapp = names_from(HykuKnapsack::Engine.root.join('hyrax-webapp'))

    expect(from_knapsack).to match_array(from_webapp)
  end

  # Temporary directories, not the real ones: a yml in config/authorities is a
  # registered authority the moment it lands, so a run that dies before cleaning
  # up would seed it into every tenant.
  it 'takes an authority from the first path that has it' do
    Dir.mktmpdir do |first|
      Dir.mktmpdir do |second|
        [first, second].each { |dir| File.write(File.join(dir, 'shared.yml'), "terms:\n") }
        allow(Qa::Authorities::Local).to receive(:subauthorities_path).and_return([first, second])

        expect(Qa::Authorities::Local::FileBasedAuthority.new('shared').send(:subauthority_filename))
          .to eq(File.join(first, 'shared.yml'))
      end
    end
  end
end
# rubocop:enable RSpec/DescribeClass
