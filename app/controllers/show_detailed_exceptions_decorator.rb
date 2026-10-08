# frozen_string_literal: true

# OVERRIDE ActionController::Rescue#show_detailed_exceptions? to show Rails' detailed error page
# to signed-in superadmins only. HYKU_SHOW_BACKTRACE showed it to every visitor, and the page
# dumps internal config, including connection credentials. Rails asks this only when
# HYKU_SHOW_BACKTRACE is off, and only for errors raised inside a controller action, so a
# routing 404 still gets the plain page.
module ShowDetailedExceptionsDecorator
  def show_detailed_exceptions?
    super || current_user&.superadmin? || false
  rescue StandardError
    false
  end
end

ApplicationController.prepend(ShowDetailedExceptionsDecorator)
