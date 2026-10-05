# frozen_string_literal: true

# OVERRIDE Hyrax 5.3.0: an ACL whose permissions match what is persisted has no pending changes,
# so the copy in Steps::Save does not rewrite it and reindex the work a second time
module Hyrax
  module AccessControlListDecorator
    def pending_changes?
      return false if change_set.resource.persisted? && change_set.permissions.to_set == change_set.model.permissions.to_set

      super
    end
  end
end

Hyrax::AccessControlList.prepend(Hyrax::AccessControlListDecorator)
