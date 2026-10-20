# frozen_string_literal: true

# OVERRIDE Bulkrax 10.0.0: read the parent work and run the update_work
# transaction under a lock per parent. Bulkrax reads the parent before any lock,
# so two file sets imported at once for one work each save a copy without the
# other, and one drops out of member_ids. The key differs from the work id
# because WorkUploadsHandler locks that inside the transaction.
module Bulkrax
  module ValkyrieObjectFactoryFileSetDecorator
    include Hyrax::Lockable

    private

    def create_file_set(attrs)
      attrs = HashWithIndifferentAccess.new(attrs)
      uploaded_files, = prep_fileset_content(attrs)
      parent_id = find_record(attributes[related_parents_parsed_mapping].first, importer_run_id).last.id

      ActiveRecord::Base.uncached do
        acquire_lock_for("bulkrax-file-set-parent:#{parent_id}") { add_to_parent(Hyrax.query_service.find_by(id: parent_id), uploaded_files, attrs) }
      end
    end

    def add_to_parent(parent, uploaded_files, attrs)
      perform_transaction_for(object: parent, attrs: {}) do
        transactions['change_set.update_work']
          .with_step_args(
            'work_resource.add_file_sets' => { uploaded_files:, file_set_params: [attrs.merge(attributes).symbolize_keys] },
            'work_resource.save_acl' => { permissions_params: [attrs.try('visibility') || 'open'].compact }
          )
      end
    end
  end
end

Bulkrax::ValkyrieObjectFactory.prepend(Bulkrax::ValkyrieObjectFactoryFileSetDecorator)
