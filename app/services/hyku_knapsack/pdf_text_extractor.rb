# frozen_string_literal: true

module HykuKnapsack
  class PdfTextExtractor
    def self.needed?(file_set, original:)
      latest?(file_set, original) && texts(file_set).none? { |text| current?(text, original) }
    end

    def self.call(file_set:, path:, original:)
      return unless needed?(file_set, original:)

      stale = texts(file_set)
      discard(file_set, stale)
      text = pdftotext(path)
      return Hyrax::ValkyriePersistDerivatives.call(text, { url: url_for(file_set), container: 'extracted_text', mime_type: 'text/plain' }) if text.present?

      Hyrax.publisher.publish('object.membership.updated', object: file_set, user: ::User.system_user) if stale.any?
    end

    def self.texts(file_set)
      Hyrax.custom_queries.find_many_file_metadata_by_use(resource: file_set, use: Hyrax::FileMetadata::Use::EXTRACTED_TEXT)
           .select { |file| file.mime_type == 'text/plain' }
    end

    def self.latest?(file_set, original)
      newest = Hyrax.custom_queries.find_many_file_metadata_by_use(resource: file_set, use: Hyrax::FileMetadata::Use::ORIGINAL_FILE)
                    .max_by { |file| file.created_at.to_f }
      newest.nil? || newest.id == original.id
    end

    def self.current?(text, original)
      return true unless original&.created_at && text.created_at

      text.created_at >= original.created_at
    end

    def self.discard(file_set, stale)
      return if stale.empty?

      file_set.file_ids -= stale.map(&:id)
      Hyrax.persister.save(resource: file_set)
      stale.each { |text| Hyrax.persister.delete(resource: text) }
    end

    def self.pdftotext(path)
      text, error, status = Open3.capture3('pdftotext', '-enc', 'UTF-8', path.to_s, '-')
      return text if status.success?

      Rails.logger.warn("pdftotext exited #{status.exitstatus} for #{path}: #{error.strip}")
      nil
    end

    def self.url_for(file_set)
      URI("file://#{Hyrax::DerivativePath.derivative_path_for_reference(file_set, 'extracted_text')}").to_s
    end
  end
end
