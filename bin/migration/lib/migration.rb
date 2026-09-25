# frozen_string_literal: true

require 'base64'
require 'csv'
require 'fileutils'
require 'json'
require 'open3'
require 'shellwords'
require 'yaml'
require 'aws-sdk-s3'
require_relative '../../../app/factories/bulkrax/utk_migration_object_key'

module Migration
  ROOT = File.expand_path('../../..', __dir__)
  WORK_DIR = File.join(ROOT, 'tmp/migration')
  PREFIX = 'derivatives'

  class << self
    def pairtree(id)
      pairs = id.scan(/../)
      File.join(*pairs[0..-2], pairs[-1])
    end
  end
end

require_relative 'migration/options'
require_relative 'migration/report'
require_relative 'migration/confirmation'
require_relative 'migration/target'
require_relative 'migration/pod'
require_relative 'migration/sheet'
require_relative 'migration/profile'
require_relative 'migration/preflight'
require_relative 'migration/transform'
require_relative 'migration/originals'
require_relative 'migration/derivatives/base'
require_relative 'migration/derivatives/stage'
require_relative 'migration/derivatives/fill'
