# frozen_string_literal: true

namespace :utk do
  namespace :relationships do
    desc 'Enqueue the relationship pass for every parent a tenant still has pending (DRY_RUN=1 to list)'
    task :resume, [:cname] => :environment do |_task, args|
      abort 'Usage: rake "utk:relationships:resume[tenant.cname]" [DRY_RUN=1]' if args[:cname].blank?

      AccountElevator.switch!(args[:cname])
      dry_run = ActiveModel::Type::Boolean.new.cast(ENV['DRY_RUN']) || false
      HykuKnapsack::PendingRelationships.call(dry_run:)
    end
  end
end
