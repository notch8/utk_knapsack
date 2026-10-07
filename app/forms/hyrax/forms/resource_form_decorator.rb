# frozen_string_literal: true

# OVERRIDE Hyrax 5.3.0: a flexible form rebuilds its profile fields on its class, which every
# instance shares, so each flexible form is built from a subclass of its own
module Hyrax
  module Forms
    module ResourceFormDecorator
      def new(*args, **kwargs, &block)
        resource = kwargs.fetch(:resource) { args.first }
        return super if per_build_class? || !resource.try(:flexible?)

        base = self
        Class.new(self) do
          @definitions = base.definitions.dup
          define_singleton_method(:name) { base.name }
          define_singleton_method(:to_s) { base.to_s }
          define_singleton_method(:inspect) { base.inspect }
          define_singleton_method(:per_build_class?) { true }
        end.new(*args, **kwargs, &block)
      end

      def per_build_class?
        false
      end
    end
  end
end

Hyrax::Forms::ResourceForm.singleton_class.prepend(Hyrax::Forms::ResourceFormDecorator)
