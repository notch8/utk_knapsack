# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'utk:relationships rake tasks' do
  before(:all) do
    Rails.application.load_tasks unless Rake::Task.task_defined?('utk:relationships:resume')
  end

  after do
    Rake::Task.tasks.each(&:reenable)
    ENV.delete('DRY_RUN')
  end

  before do
    allow(AccountElevator).to receive(:switch!)
    allow(HykuKnapsack::PendingRelationships).to receive(:call).and_return(0)
  end

  it 'switches to the tenant and resumes its pending relationships' do
    ENV['DRY_RUN'] = '1'
    Rake::Task['utk:relationships:resume'].invoke('dev.example.org')

    expect(AccountElevator).to have_received(:switch!).with('dev.example.org')
    expect(HykuKnapsack::PendingRelationships).to have_received(:call).with(dry_run: true)
  end

  it 'aborts without a tenant' do
    expect { Rake::Task['utk:relationships:resume'].invoke }.to raise_error(SystemExit).and output(/Usage/).to_stderr
  end
end
