# frozen_string_literal: true

# OVERRIDE Hyrax v5.3.0 to render each creators/contributors entry on one line
# as "Role: Name" instead of a "Name:" line above a "Role:" line.
#
# The role takes the place of the sub-property label, so an entry reads the way
# the surrounding metadata list does, with the role emphasized like a term
# heading. An entry with no role renders the name on its own.
module Hyrax
  module Renderers
    module CompoundAttributeRendererDecorator
      ROLE_KEY = 'role'
      NAME_KEY = 'name'

      private

      def entry_markup(entry)
        return super unless role_and_name_entry?(entry)

        pairs = entry_to_pairs(entry).to_h
        name = pairs[NAME_KEY]
        role = pairs[ROLE_KEY]

        %(<div class="hyrax-compound-entry">#{role_and_name_markup(role, name)}</div>)
      end

      # Only the name/role shape collapses to one line; any other compound keeps
      # the upstream one-line-per-sub-property rendering.
      def role_and_name_entry?(entry)
        keys = entry_to_pairs(entry).map(&:first)
        keys.include?(NAME_KEY) && (keys - [NAME_KEY, ROLE_KEY]).empty?
      end

      # Both halves render the value as indexed rather than resolving it through
      # the sub-property's authority: the show page reads from Solr, and a role
      # whose id predates an authority edit has no term to resolve to, so a
      # lookup would silently fall back to the same stored string anyway.
      def role_and_name_markup(role, name)
        value = %(<span class="hyrax-compound-subproperty-value">#{ERB::Util.h(name)}</span>)
        return value if role.blank?

        label = %(<span class="hyrax-compound-subproperty-label">#{ERB::Util.h(role)}:</span> )
        %(<div class="hyrax-compound-subproperty">#{label}#{value}</div>)
      end
    end
  end
end

Hyrax::Renderers::CompoundAttributeRenderer.prepend(
  Hyrax::Renderers::CompoundAttributeRendererDecorator
)
