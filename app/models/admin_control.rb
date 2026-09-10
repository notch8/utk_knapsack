# frozen_string_literal: true

# A Valkyrie-native admin set model for installations that never used Fedora.
#
# Unlike AdminSetResource, whose name disambiguated it from an ActiveFedora
# `AdminSet` twin, this class has no ActiveFedora counterpart and must not
# acquire one: it is deliberately free of Wings mappings so that removing Wings
# is a no-op for it.
class AdminControl < Hyrax::AdministrativeSet
  include Hyrax::ArResource
  include Hyrax::Permissions::Readable

  include WithPermissionTemplateShim

  def member_of
    Hyrax.query_service.find_inverse_references_by(resource: self, property: :admin_set_id)
  end

  def member_collection_ids
    member_of.map(&:id)
  end
end
