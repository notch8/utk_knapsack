# frozen_string_literal: true

# OVERRIDE Hyku: skip a file set characterized before it has a parent work, as Bulkrax
# imports attach file sets only in the relationship pass
module HyraxListenerDecorator
  private

  def pdf_viewer_and_download_button(event)
    return unless Hyrax.custom_queries.find_parent_work(resource: event[:file_set])

    super
  end
end

HyraxListener.prepend(HyraxListenerDecorator)
