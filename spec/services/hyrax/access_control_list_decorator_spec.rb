# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Hyrax::AccessControlListDecorator do
  let(:resource) { Hyrax.persister.save(resource: Pdf.new) }
  let(:acl) { Hyrax::AccessControlList.new(resource:) }

  def permission(mode, agent)
    Hyrax::Permission.new(access_to: resource.id, mode:, agent:)
  end

  before do
    original = Hyrax::AccessControlList.new(resource:)
    original << permission(:edit, 'group/admin')
    original << permission(:read, 'group/public')
    original.save
    allow(Hyrax.publisher).to receive(:publish).and_call_original
  end

  context 'when the persisted permissions are assigned back in another order' do
    before { acl.permissions = acl.permissions.to_a.reverse }

    it 'has no pending changes' do
      expect(acl.pending_changes?).to be false
    end

    it 'saves without publishing an ACL update' do
      acl.save
      expect(Hyrax.publisher).not_to have_received(:publish).with('object.acl.updated', any_args)
    end
  end

  context 'when a permission is added' do
    before { acl << permission(:read, 'group/registered') }

    it 'publishes an ACL update on save' do
      acl.save
      expect(Hyrax.publisher).to have_received(:publish).with('object.acl.updated', hash_including(result: :success))
    end
  end

  context 'when the resource has no ACL yet' do
    let(:acl) { Hyrax::AccessControlList.new(resource: Hyrax.persister.save(resource: Pdf.new)) }

    it 'has pending changes' do
      expect(acl.pending_changes?).to be true
    end
  end
end
