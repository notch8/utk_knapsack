# frozen_string_literal: true

# OVERRIDE Hyrax 5.3.0: on a FITS conflict, keep only the identities of the MIME type the most tools
# report (the first listed on a tie), so mime_type and format_label are not the outlier's
module HykuKnapsack
  module ValkyrieCharacterizationServiceDecorator
    protected

    def parse_metadata(metadata)
      super(majority_identity(metadata))
    end

    private

    def majority_identity(metadata)
      xml = Nokogiri::XML(metadata.to_s)
      identification = xml.at_css('fits > identification[status="CONFLICT"]')
      return metadata unless identification

      groups = identification.css('> identity').group_by { |identity| identity['mimetype'].to_s.split(',').first }.values
      majority = groups.each_with_index.max_by { |group, index| [group.sum { |identity| identity.css('> tool').size }, -index] }.first
      (groups.flatten - majority).each(&:remove)
      xml.to_xml
    end
  end
end

Hyrax::Characterization::ValkyrieCharacterizationService.prepend(HykuKnapsack::ValkyrieCharacterizationServiceDecorator)
