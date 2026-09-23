# frozen_string_literal: true

module Bulkrax
  # OVERRIDE Bulkrax 9.5.1: `add_child_to_parent_work` returns `true` rather
  # than the parent when the child is already a member, and
  # {Bulkrax::CreateRelationshipsJob} hands that return value back as a
  # resource. Any relationship pass that revisits an existing membership then
  # dies in Valkyrie's resource converter with `undefined method 'id' for true`.
  module ValkyrieObjectFactoryDecorator
    def add_child_to_parent_work(parent:, child:)
      result = super
      result == true ? find(parent.id) : result
    end
  end
end

Bulkrax::ValkyrieObjectFactory.singleton_class.prepend(Bulkrax::ValkyrieObjectFactoryDecorator)
