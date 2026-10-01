# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'utk:derivatives rake tasks' do
  before(:all) do
    Rails.application.load_tasks unless Rake::Task.task_defined?('utk:derivatives:generate_missing_thumbnails')
  end

  after do
    Rake::Task.tasks.each(&:reenable)
    ENV.delete('DRY_RUN')
    ENV.delete('LIMIT')
  end

  describe 'utk:derivatives:generate_missing_thumbnails' do
    before do
      allow(AccountElevator).to receive(:switch!)
      allow(HykuKnapsack::MissingThumbnails).to receive(:call).and_return(0)
    end

    it 'switches to the tenant and runs the finder' do
      Rake::Task['utk:derivatives:generate_missing_thumbnails'].invoke('dev.example.org')

      expect(AccountElevator).to have_received(:switch!).with('dev.example.org')
      expect(HykuKnapsack::MissingThumbnails).to have_received(:call).with(dry_run: false, limit: nil)
    end

    it 'passes DRY_RUN and LIMIT through' do
      ENV['DRY_RUN'] = '1'
      ENV['LIMIT'] = '25'

      Rake::Task['utk:derivatives:generate_missing_thumbnails'].invoke('dev.example.org')

      expect(HykuKnapsack::MissingThumbnails).to have_received(:call).with(dry_run: true, limit: 25)
    end

    it 'reads DRY_RUN=0 and DRY_RUN=false as a real run' do
      %w[0 false].each do |value|
        ENV['DRY_RUN'] = value
        Rake::Task['utk:derivatives:generate_missing_thumbnails'].reenable
        Rake::Task['utk:derivatives:generate_missing_thumbnails'].invoke('dev.example.org')
      end

      expect(HykuKnapsack::MissingThumbnails).to have_received(:call).with(dry_run: false, limit: nil).twice
    end

    it 'refuses a LIMIT that is not a number' do
      ENV['LIMIT'] = 'abc'

      expect { Rake::Task['utk:derivatives:generate_missing_thumbnails'].invoke('dev.example.org') }
        .to raise_error(ArgumentError)
      expect(HykuKnapsack::MissingThumbnails).not_to have_received(:call)
    end

    it 'aborts without a tenant' do
      expect { Rake::Task['utk:derivatives:generate_missing_thumbnails'].invoke }
        .to raise_error(SystemExit).and output(/Usage/).to_stderr
      expect(HykuKnapsack::MissingThumbnails).not_to have_received(:call)
    end
  end
end
