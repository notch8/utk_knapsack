# frozen_string_literal: true

namespace :utk do
  namespace :derivatives do
    desc 'Enqueue thumbnail derivatives for a tenant\'s file sets that should have one and do not (DRY_RUN=1, LIMIT=n)'
    task :generate_missing_thumbnails, [:cname] => :environment do |_task, args|
      usage = 'Usage: rake "utk:derivatives:generate_missing_thumbnails[tenant.cname]" [DRY_RUN=1] [LIMIT=n]'
      abort usage if args[:cname].blank?

      AccountElevator.switch!(args[:cname])
      dry_run = ActiveModel::Type::Boolean.new.cast(ENV['DRY_RUN']) || false
      HykuKnapsack::MissingThumbnails.call(dry_run:, limit: ENV['LIMIT'].presence && Integer(ENV['LIMIT']))
    end

    desc 'Enqueue text extraction for a tenant\'s PDF file sets that have no plain-text derivative (DRY_RUN=1; LIMIT=n is a smoke test only, run unbounded to backfill)'
    task :extract_missing_pdf_text, [:cname] => :environment do |_task, args|
      usage = 'Usage: rake "utk:derivatives:extract_missing_pdf_text[tenant.cname]" [DRY_RUN=1] [LIMIT=n]'
      abort usage if args[:cname].blank?

      AccountElevator.switch!(args[:cname])
      dry_run = ActiveModel::Type::Boolean.new.cast(ENV['DRY_RUN']) || false
      HykuKnapsack::MissingPdfText.call(dry_run:, limit: ENV['LIMIT'].presence && Integer(ENV['LIMIT']))
    end
  end
end
