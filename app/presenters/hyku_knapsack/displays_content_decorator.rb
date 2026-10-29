# frozen_string_literal: true

# OVERRIDE Hyrax 5.3.0: give the audio canvas thumbnail a scheme and a digest; production serves only digested
# assets. Remove once the pin includes samvera/hyrax#7726.
module HykuKnapsack
  module DisplaysContentDecorator
    private

    def audio_content
      super.tap do |content|
        content.thumbnail.first[:id] = URI.join(content.url, ActionController::Base.helpers.image_path('audio.png')).to_s
      end
    end
  end
end

Hyrax::IiifManifestPresenter::DisplayImagePresenter.prepend(HykuKnapsack::DisplaysContentDecorator)
