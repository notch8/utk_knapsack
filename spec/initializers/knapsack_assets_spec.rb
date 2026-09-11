# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable RSpec/DescribeClass
RSpec.describe 'config/initializers/knapsack_assets.rb' do
  let(:knapsack_root) { HykuKnapsack::Engine.root.to_s }

  # The environment `assets:precompile` builds, which is not the one the running
  # server holds: with `config.assets.compile = false` (production's setting)
  # `Rails.application.assets` is never assigned, and the rake task builds its
  # own from `config.assets.paths`. Resolving through this shape is the only way
  # to catch an override that works in development and vanishes on deploy.
  let(:precompile_environment) { Sprockets::Railtie.build_environment(Rails.application) }

  # Raises rather than returning nil, so a path that is missing altogether fails
  # as itself instead of as a NoMethodError from comparing nil.
  def index_of(paths, fragment)
    paths.map(&:to_s).index { |path| path.include?(fragment) } ||
      raise("no asset search path contains #{fragment.inspect}")
  end

  it 'puts the knapsack asset tree in the search paths' do
    expect(Rails.application.config.assets.paths)
      .to include(HykuKnapsack::Engine.root.join('app', 'assets', 'javascripts').to_s)
  end

  # The assertion that actually bites. Membership in `config.assets.paths` is not
  # enough and does not imply order: measured there, Hyku's javascripts sit at
  # index 1 and the knapsack's at 8 whether or not the fix is in place. Only the
  # built environment reflects the configure block.
  it 'searches the knapsack javascripts ahead of the app\'s' do
    paths = precompile_environment.paths
    knapsack = index_of(paths, "#{knapsack_root}/app/assets/javascripts")
    app = index_of(paths, 'hyrax-webapp/app/assets/javascripts')

    expect(knapsack).to be < app
  end

  # Compared exactly, not with start_with: Hyku sits *inside* the knapsack at
  # `<root>/hyrax-webapp`, so a prefix match is satisfied by the file this
  # override exists to beat.
  it 'resolves a path Hyku also ships to the knapsack copy' do
    filename = precompile_environment.find_asset('codemirror-autorefresh.js')&.filename.to_s

    expect(filename).to eq HykuKnapsack::Engine.root.join('app', 'assets', 'javascripts', 'codemirror-autorefresh.js').to_s
  end

  # The sequence sort is not reachable from `application.js`, so it only ships if
  # it is named in `precompile`. Development compiles it on demand either way,
  # which is exactly how a missing entry stays invisible until deploy.
  it 'builds the file manager sequence sort, which no manifest requires' do
    filename = precompile_environment.find_asset('hyku_knapsack/file_manager_sequence_sort.js')&.filename.to_s

    expect(filename)
      .to eq HykuKnapsack::Engine.root.join('app', 'assets', 'javascripts', 'hyku_knapsack', 'file_manager_sequence_sort.js').to_s
  end

  it 'names the file manager sequence sort for precompilation' do
    expect(Rails.application.config.assets.precompile).to include('hyku_knapsack/file_manager_sequence_sort.js')
  end

  it 'names it once, though the initializer is evaluated more than once per boot' do
    entries = Rails.application.config.assets.precompile.count('hyku_knapsack/file_manager_sequence_sort.js')

    expect(entries).to eq 1
  end
end
# rubocop:enable RSpec/DescribeClass
