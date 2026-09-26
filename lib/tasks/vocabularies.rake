# frozen_string_literal: true

# Replaces a vocabulary outright rather than merging into it: the shipped yml is the whole
# truth, so the rows are rebuilt from it and anything a tenant added is dropped.
class VocabularyReload
  def initialize(file:, dry_run:)
    @file = file
    @dry_run = dry_run
    parsed = YAML.safe_load(File.read(file))
    @terms = Array.wrap(parsed['terms'])
    @description = parsed['description']
  end

  attr_reader :terms

  def call(account, name)
    AccountElevator.switch!(account.cname)
    vocabulary = Qa::LocalAuthority.find_by(name:)

    # Seeded vocabularies only. A tenant without this one gets it from
    # LocalVocabularyService the first time it is created, terms included.
    return "· #{account.cname}: no #{name} vocabulary, skipped" if vocabulary.nil?

    existing = vocabulary.local_authority_entries.count
    summary = "#{existing} removed, #{@terms.size} added"
    return "· #{account.cname}: would apply #{summary}" if @dry_run

    replace(vocabulary)
    "✓ #{account.cname}: #{summary}"
  end

  private

  def replace(vocabulary)
    vocabulary.with_lock do
      vocabulary.local_authority_entries.delete_all
      @terms.each_with_index { |term, index| create_entry(vocabulary, term, index) }
      # LocalVocabularyService backfills a description only while it is blank, so a
      # changed wording reaches an existing tenant here or not at all.
      vocabulary.update!(description: @description) if @description.present?
    end
  end

  # Positions run from one, the way the model numbers a term added through the dashboard.
  def create_entry(vocabulary, term, index)
    vocabulary.local_authority_entries.create!(
      uri: term['id'],
      label: term['term'],
      active: term.fetch('active', true),
      position: index + 1,
      data: term.except('id', 'term', 'active')
    )
  end
end

namespace 'utk:vocabularies' do
  desc 'Rebuild a vocabulary from its config/authorities yml, on every tenant that has it ' \
       '(NAME=resource_types, optional TENANT=cname, DRY_RUN=true)'
  task reload: :environment do
    name = ENV.fetch('NAME') { abort 'Usage: rake utk:vocabularies:reload NAME=resource_types' }
    # Resolved here rather than through `subauthority_filename`, which answers with the
    # search path itself when nothing matches, and can answer relatively, which would
    # read whichever file the working directory happens to hold.
    file = Qa::Authorities::Local.subauthorities_path
                                 .map { |dir| File.expand_path(File.join(dir, "#{name}.yml")) }
                                 .find { |path| File.exist?(path) }
    abort "No #{name}.yml in #{Qa::Authorities::Local.subauthorities_path.join(', ')}" if file.blank?

    dry_run = ActiveModel::Type::Boolean.new.cast(ENV.fetch('DRY_RUN', false))
    reload = VocabularyReload.new(file:, dry_run:)
    abort "#{file} lists no terms" if reload.terms.empty?

    puts "Reading #{file}#{' (dry run)' if dry_run}"

    accounts = Account.full_accounts
    accounts = accounts.where(cname: ENV['TENANT']) if ENV['TENANT']
    abort "No account matches TENANT=#{ENV['TENANT']}" if accounts.none?

    accounts.find_each { |account| puts reload.call(account, name) }
  end
end
