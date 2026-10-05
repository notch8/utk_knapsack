# frozen_string_literal: true

# OVERRIDE Hyrax 5.3.0 to serialize a Valkyrie resource without Wings.
json.merge! @curation_concern.attributes.except(:id, :new_record, :internal_resource)
json.id @curation_concern.id.to_s
json.version @curation_concern.try(:etag)
