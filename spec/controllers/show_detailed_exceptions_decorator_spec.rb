# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ShowDetailedExceptionsDecorator do
  subject(:controller) { ApplicationController.new }

  before { allow(controller).to receive(:current_user).and_return(user) }

  context 'with nobody signed in' do
    let(:user) { nil }

    it { expect(controller.show_detailed_exceptions?).to be false }
  end

  context 'with a user who is not a superadmin' do
    let(:user) { instance_double(User, superadmin?: false) }

    it { expect(controller.show_detailed_exceptions?).to be false }
  end

  context 'with a superadmin' do
    let(:user) { instance_double(User, superadmin?: true) }

    it { expect(controller.show_detailed_exceptions?).to be true }
  end

  context 'when looking up the user fails' do
    let(:user) { nil }

    before { allow(controller).to receive(:current_user).and_raise(ActiveRecord::ConnectionNotEstablished) }

    it { expect(controller.show_detailed_exceptions?).to be false }
  end
end
