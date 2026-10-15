# frozen_string_literal: true

require_relative 'spec_helper'
require 'open3'
require 'tmpdir'

RSpec.describe 'pod/download.rb' do
  let(:script) { File.expand_path('../lib/migration/pod/download.rb', __dir__) }

  it 'reports a file it cannot reach as failed and carries on with the rest' do
    Dir.mktmpdir do |root|
      File.write(File.join(root, 'kept.txt'), 'abc')
      jobs = "https://127.0.0.1:1/unreachable\tlost.txt\t3\nhttps://127.0.0.1:1/unused\tkept.txt\t3\n"

      out, _err, status = Open3.capture3({ 'HYRAX_DERIVATIVES_PATH' => root }, 'ruby', script, stdin_data: jobs)

      expect(status).to be_success
      expect(out.lines).to eq(["failed Errno::ECONNREFUSED\tlost.txt\n", "present\tkept.txt\n"])
    end
  end
end
