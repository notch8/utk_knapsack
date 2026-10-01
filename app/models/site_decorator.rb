# frozen_string_literal: true

# OVERRIDE Hyku: Hyrax's request-scoped schema memos hold rows from the tenant they were read under
module SiteDecorator
  def reset!
    super
    Hyrax::Current.flexible_schema = nil
    Hyrax::Current.flexible_schemas_by_version = nil
  end
end

Site.singleton_class.prepend(SiteDecorator)
