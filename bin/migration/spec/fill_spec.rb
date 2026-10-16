# frozen_string_literal: true

require_relative 'spec_helper'
require 'tmpdir'

RSpec.describe Migration::Derivatives::Fill do
  let(:report) { instance_double(Migration::Report, item: nil, failures: nil) }
  let(:progress) { instance_double(Migration::Progress, cursor: 1, advance!: nil) }
  let(:listed) { [] }

  let(:root) { Dir.mktmpdir }

  before do
    stub_const('ENV', ENV.to_h.merge('BATCH' => '1', 'DST_ROOT' => root))
    Aws.config.update(stub_responses: { list_objects_v2: ->(context) { listed << context.params[:prefix] && { contents: [] } } })
  end

  after do
    Aws.config.delete(:stub_responses)
    FileUtils.rm_rf(root)
  end

  it 'resumes after the file sets an earlier run finished and moves the cursor batch by batch' do
    fill = described_class.new(Migration::Target.for(nil), report)

    expect { fill.call(%w[aa-one bb-two cc-three], progress) }.to output.to_stderr
    expect(listed.map { |prefix| prefix.split('/', 2).last }).to eq(["#{Migration.pairtree('bb-two')}-", "#{Migration.pairtree('cc-three')}-"])
    expect(progress).to have_received(:advance!).with('fill', 1).twice
  end

  it 'stops moving the cursor once a download fails, so a rerun retries it' do
    Aws.config.update(stub_responses: {
                        list_objects_v2: { contents: [{ key: "derivatives/#{Migration.pairtree('bb-two')}-thumbnail.jpeg", size: 3 }] },
                        get_object: 'NoSuchKey'
                      })
    fill = described_class.new(Migration::Target.for(nil), report)

    expect { fill.call(%w[aa-one bb-two cc-three], progress) }.to output.to_stderr
    expect(progress).not_to have_received(:advance!)
  end
end
