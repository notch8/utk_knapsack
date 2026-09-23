# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Bulkrax::ValkyrieObjectFactoryDecorator do
  let(:child)  { Hyrax::FileSet.new(id: ::Valkyrie::ID.new('child-id')) }
  let(:parent) { StillImage.new(id: ::Valkyrie::ID.new('parent-id'), member_ids:) }

  before { allow(Bulkrax::ValkyrieObjectFactory).to receive(:find).with(parent.id).and_return(parent) }

  context 'when the child is already a member' do
    let(:member_ids) { [child.id] }

    it 'returns the parent rather than true' do
      result = Bulkrax::ValkyrieObjectFactory.add_child_to_parent_work(parent:, child:)

      expect(result.id.to_s).to eq 'parent-id'
    end
  end
end
