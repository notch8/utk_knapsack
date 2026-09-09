# frozen_string_literal: true

# A Valkyrie-native collection model for installations that never used Fedora.
#
# Unlike CollectionResource, whose name disambiguated it from an ActiveFedora
# `::Collection` twin, this class has no ActiveFedora counterpart and must not
# acquire one: it is deliberately free of Wings mappings so that removing Wings
# is a no-op for it.
class DigitalCollection < Hyrax::PcdmCollection
  if Hyrax.config.collection_include_metadata?
    include Hyrax::Schema(:basic_metadata)
    include Hyrax::Schema(:bulkrax_metadata)
    include Hyrax::Schema(:collection_resource)
    include Hyrax::Schema(:with_thumbnail)
    include Hyrax::Schema(:compound_metadata) unless Hyrax.config.flexible?
  end
  include Hyrax::ArResource

  include Hyrax::Permissions::Readable

  include WithPermissionTemplateShim

  def creator
    OrderAlready::InputOrderSerializer.deserialize(@attributes[:creator])
  end

  def creator=(values)
    set_value(:creator, OrderAlready::InputOrderSerializer.serialize(values))
  end

  ##
  # @return [Enumerator]
  def members_of
    return [] unless persisted?

    Hyrax.query_service.custom_queries.find_members_of(collection: self)
  end

  ##
  # @return [Array]
  def member_collection_ids
    return [] unless persisted?

    Hyrax.query_service.custom_queries.find_child_collection_ids(resource: self).to_a
  end

  def collection_type
    Hyrax::CollectionType.for(collection: self)
  end
end
