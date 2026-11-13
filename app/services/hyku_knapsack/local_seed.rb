# frozen_string_literal: true

require 'digest'
require 'open-uri'
require 'rubygems/package'

module HykuKnapsack
  class LocalSeed
    ADMIN_EMAIL = 'admin@example.com'
    BUNDLE_URL = 'https://drive.usercontent.google.com/download?id=1DjZHW-7gYQBwOFaazU-NM1zSixLAdCms&export=download&confirm=t'
    BUNDLE_SHA256 = '9479cb08801236f34ab64f6b989933ffcdfef71ca94f74fe026906ea30521dae'

    class << self
      def call(**options)
        new(**options).call
      end
    end

    def initialize(name: 'dev', bundle_url: BUNDLE_URL, sha256: BUNDLE_SHA256, dir: HykuKnapsack::Engine.root.join('tmp/seed', sha256), io: $stdout)
      @name = name
      @bundle_url = bundle_url
      @sha256 = sha256
      @dir = Pathname(dir)
      @io = io
    end

    def call
      raise 'utk:seed_local refuses to run in production' if Rails.env.production?

      fetch_bundle
      admin = seed_admin
      account = seed_account
      AccountElevator.switch!(account.cname)
      CreateAccount.new(account, [admin]).add_initial_users
      Hyrax::FlexibleSchema.create_default_schema
      seed_site(account)
      seed_branding
      Records.call(dir:, io:)
      seed_featured
      io.puts("Seeded #{account.cname}; derivatives are running in the worker")
      account
    end

    private

    attr_reader :name, :bundle_url, :sha256, :dir, :io

    def fetch_bundle
      return if dir.exist?

      io.puts("Downloading #{bundle_url}")
      partial = Pathname("#{dir}.partial")
      FileUtils.rm_rf(partial)
      URI.parse(bundle_url).open do |download|
        verify(download)
        Zlib::GzipReader.wrap(download) { |gzip| extract(gzip, partial) }
      end
      FileUtils.mv(partial, dir)
    end

    def verify(download)
      raise "Bundle checksum does not match #{sha256}" unless Digest::SHA256.hexdigest(download.read) == sha256

      download.rewind
    end

    def extract(gzip, into)
      Gem::Package::TarReader.new(gzip).each do |entry|
        next unless entry.file?

        path = into.join(entry.full_name).expand_path
        raise "Refusing to extract #{entry.full_name} outside #{into}" unless path.to_s.start_with?("#{into.expand_path}/")

        FileUtils.mkdir_p(path.dirname)
        File.binwrite(path, entry.read)
      end
    end

    def site_manifest
      @site_manifest ||= JSON.parse(dir.join('site.json').read)
    end

    def seed_admin
      User.find_or_create_by!(email: ADMIN_EMAIL) { |user| user.password = 'testing123' }.tap do |user|
        user.add_role(:superadmin) unless user.superadmin?
      end
    end

    def seed_account
      Account.find_by(name:) || Account.new(name:, tenant: SecureRandom.uuid, is_public: true).tap do |account|
        CreateAccount.new(account).save || raise("Account creation failed: #{account.errors.full_messages.to_sentence}")
      end
    end

    def seed_site(account)
      account.update!(settings: account.settings.merge(site_manifest['settings']))
      site = Site.instance
      site.assign_attributes(site_manifest['site'])
      dir.join(site_manifest['logo_image']).open do |logo|
        dir.join(site_manifest['favicon']).open { |favicon| site.update!(logo_image: logo, favicon:) }
      end
      seed_features_and_blocks
    end

    def seed_features_and_blocks
      site_manifest['features'].each { |key, enabled| Hyrax::Feature.find_or_initialize_by(key:).update!(enabled:) }
      site_manifest['content_blocks'].each { |block, value| ContentBlock.find_or_initialize_by(name: block).update!(value:) }
    end

    def seed_branding
      site_manifest['branding'].each do |branding|
        next if CollectionBrandingInfo.exists?(collection_id: branding['collection_id'], role: branding['role'])

        Dir.mktmpdir do |tmp|
          copy = Pathname(tmp).join(File.basename(branding['file']))
          FileUtils.cp(dir.join(branding['file']), copy)
          CollectionBrandingInfo.new(collection_id: branding['collection_id'], filename: copy.basename.to_s, role: branding['role'],
                                     alt_txt: branding['alt_text'], target_url: branding['target_url']).save(copy.to_s)
        end
      end
    end

    def seed_featured
      site_manifest['featured_collections'].each_with_index do |collection_id, order|
        FeaturedCollection.find_or_create_by!(collection_id:) { |featured| featured.order = order }
      end
    end
  end
end
