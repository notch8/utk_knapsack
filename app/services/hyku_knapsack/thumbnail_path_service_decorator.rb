# frozen_string_literal: true

# OVERRIDE Hyrax 5.3.0: a Valkyrie audio file set has no thumbnail_id, so check for audio before
# falling back to the default image
module HykuKnapsack
  module ThumbnailPathServiceDecorator
    def call(object)
      return audio_image if object.try(:file_set?) && audio?(object)

      super
    end
  end
end

Hyrax::ThumbnailPathService.singleton_class.prepend(HykuKnapsack::ThumbnailPathServiceDecorator)
