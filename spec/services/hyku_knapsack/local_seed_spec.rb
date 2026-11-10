# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HykuKnapsack::LocalSeed do
  let(:root) { Pathname(Dir.mktmpdir) }
  let(:dir) { root.join('seed') }
  let(:url) { 'https://example.com/seed.tar.gz' }

  after { root.rmtree }

  def bundle(entries)
    tar = StringIO.new
    Gem::Package::TarWriter.new(tar) do |writer|
      entries.each { |name, body| writer.add_file_simple(name, 0o644, body.bytesize) { |io| io.write(body) } }
    end
    gzip = StringIO.new
    Zlib::GzipWriter.wrap(gzip) { |gz| gz.write(tar.string) }
    stub_request(:get, url).to_return(body: gzip.string)
    Digest::SHA256.hexdigest(gzip.string)
  end

  def fetch(sha256)
    described_class.new(bundle_url: url, sha256:, dir:, io: StringIO.new).send(:fetch_bundle)
  end

  it 'refuses to run in production' do
    allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))

    expect { described_class.call(dir:, io: StringIO.new) }.to raise_error(/refuses to run in production/)
  end

  it 'unpacks the bundle into its directory' do
    fetch(bundle('records.json' => '[]', 'files/abc' => 'bytes'))

    expect(dir.join('files/abc').read).to eq('bytes')
  end

  it 'refuses an entry that would land outside its directory and leaves no bundle behind' do
    sha256 = bundle('records.json' => '[]', '../escaped' => 'bytes')

    expect { fetch(sha256) }.to raise_error(/Refusing to extract/)
    expect(root.join('escaped')).not_to exist
    expect(dir).not_to exist
  end

  it 'refuses a bundle whose checksum does not match and leaves no bundle behind' do
    bundle('records.json' => '[]')

    expect { fetch('0' * 64) }.to raise_error(/checksum does not match/)
    expect(dir).not_to exist
  end

  describe 'seeding a tenant' do
    let(:name) { "seed#{SecureRandom.hex(3)}" }
    let(:collection_id) { SecureRandom.uuid }
    let(:images) { Rails.root.join('spec', "fixtures", "images") }

    before do
      dir.join('site').mkpath
      dir.join('branding').mkpath
      FileUtils.cp(images.join('nypl-hydra-of-lerna.jpg'), dir.join('site/logo.jpg'))
      FileUtils.cp(images.join('favicon.png'), dir.join('site/favicon.png'))
      FileUtils.cp(images.join('nypl-hydra-of-lerna.jpg'), dir.join('branding/banner.jpg'))
      dir.join('site.json').write({
        site: { application_name: 'Seeded Collections', home_theme: 'digital_collection' },
        settings: { allow_downloads: '1' },
        features: { show_share_button: false },
        content_blocks: { about_page: '<p>About the seed</p>' },
        logo_image: 'site/logo.jpg',
        favicon: 'site/favicon.png',
        branding: [{ collection_id:, role: 'banner', file: 'branding/banner.jpg', alt_text: '', target_url: '' }],
        featured_collections: [collection_id]
      }.to_json)
      allow(described_class::Records).to receive(:call)
    end

    after do
      Apartment::Tenant.switch!(Apartment.default_tenant)
      Account.find_by(name:)&.then { |account| CleanupAccountJob.perform_now(account) }
    end

    it 'builds the tenant, its admin and its site, and adds nothing on a second run' do
      2.times { described_class.call(name:, dir:, io: StringIO.new) }

      account = Account.find_by(name:)
      admin = User.find_by(email: described_class::ADMIN_EMAIL)
      expect(Account.where(name:).count).to eq(1)
      expect(Apartment::Tenant.current).to eq(account.tenant)
      expect(admin).to be_superadmin
      expect(admin.has_role?(:admin, Site.instance)).to be(true)
      expect(Hyrax::Group.find_by(name: ::Ability.admin_group_name).members).to include(admin)
      expect(Site.instance.application_name).to eq('Seeded Collections')
      expect(Site.instance.logo_image).to be_present
      expect(account.reload.settings['allow_downloads']).to eq('1')
      expect(Hyrax::Feature.find_by(key: 'show_share_button').enabled).to be(false)
      expect(ContentBlock.find_by(name: 'about_page').value).to eq('<p>About the seed</p>')
      expect(CollectionBrandingInfo.where(collection_id:).count).to eq(1)
      expect(FeaturedCollection.where(collection_id:).count).to eq(1)
      expect(described_class::Records).to have_received(:call).with(dir:, io: anything).twice
    end
  end
end
