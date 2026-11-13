# frozen_string_literal: true

namespace :utk do
  desc 'Seed a local tenant (default "dev") with a slice of production: users, site, collections, works and files'
  task :seed_local, [:name] => :environment do |_task, args|
    abort 'utk:seed_local refuses to run in production' if Rails.env.production?

    Rake::Task['utk:uri_cache:import'].invoke
    HykuKnapsack::LocalSeed.call(name: args[:name].presence || 'dev')
  end
end
