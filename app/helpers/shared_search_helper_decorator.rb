# frozen_string_literal: true

# OVERRIDE Hyku v7.2.0 SharedSearchHelper#extract_model_info: links this tenant's works to its current cname, not the one indexed with them.
#   Keep: not fixed upstream.
module SharedSearchHelperDecorator
  private

  def extract_model_info(model, request)
    id, base_route_name, account_cname = super
    [id, base_route_name, HykuKnapsack::IndexedCname.current(account_cname)]
  end
end

SharedSearchHelper.prepend(SharedSearchHelperDecorator)
