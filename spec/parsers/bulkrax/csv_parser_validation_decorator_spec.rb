# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Bulkrax::CsvParserValidationDecorator do
  let(:csv) { Tempfile.new(['update', '.csv']) }
  let(:rights) { 'http://rightsstatements.org/vocab/InC/1.0/' }
  let(:filled) { Hyrax.persister.save(resource: StillImage.new(title: ['Filled'], provider: ['UTK'], rights_statement: [rights])) }
  let(:unfilled) { Hyrax.persister.save(resource: StillImage.new(title: ['Unfilled'], rights_statement: [rights])) }

  after { csv.close! }

  def missing_fields(rows)
    File.write(csv.path, "id,model,title\n#{rows.map { |id| "#{id},StillImage,Updated" }.join("\n")}\n")
    Bulkrax::CsvParser.validate_csv(csv_file: csv.path)[:missingRequired]
                      .filter_map { |entry| entry[:field] if entry[:model] == 'StillImage' }
  end

  it 'does not ask an update-only sheet for columns its works already fill' do
    expect(missing_fields([filled.id])).not_to include('provider', 'rights_statement')
  end

  it 'finds an existing work by its source identifier' do
    Hyrax.persister.save(resource: StillImage.new(title: ['Sourced'], provider: ['UTK'], rights_statement: [rights], bulkrax_identifier: ['utk-564']))
    File.write(csv.path, "source_identifier,model,title\nutk-564,StillImage,Updated\n")

    fields = Bulkrax::CsvParser.validate_csv(csv_file: csv.path)[:missingRequired].map { |entry| entry[:field] }
    expect(fields).not_to include('provider', 'rights_statement')
  end

  it 'treats a row whose id matches nothing as new, as import does' do
    Hyrax.persister.save(resource: StillImage.new(title: ['Sourced'], provider: ['UTK'], rights_statement: [rights], bulkrax_identifier: ['utk-564']))
    File.write(csv.path, "id,source_identifier,model,title\nno-such-id,utk-564,StillImage,Updated\n")

    fields = Bulkrax::CsvParser.validate_csv(csv_file: csv.path)[:missingRequired].map { |entry| entry[:field] }
    expect(fields).to include('provider', 'rights_statement')
  end

  it 'still asks for a column an existing work has no value for' do
    expect(missing_fields([filled.id, unfilled.id])).to include('provider')
  end

  it 'judges each model by its own rows' do
    pdf = Hyrax.persister.save(resource: Pdf.new(title: ['Filled'], provider: ['UTK'], rights_statement: [rights]))
    File.write(csv.path, "id,model,title\n#{pdf.id},Pdf,Updated\n,StillImage,New\n")

    missing = Bulkrax::CsvParser.validate_csv(csv_file: csv.path)[:missingRequired].map { |entry| [entry[:model], entry[:field]] }
    expect(missing).to include(%w[StillImage provider], %w[StillImage rights_statement])
    expect(missing).not_to include(%w[Pdf provider], %w[Pdf rights_statement])
  end

  it 'still asks for the columns when a row creates a work' do
    expect(missing_fields([filled.id, ''])).to include('provider', 'rights_statement')
  end
end
