# frozen_string_literal: true

# Give the knapsack's asset tree precedence over the app's. Registered once: the
# engine re-loads knapsack initializers on top of the pass Rails already ran for
# them, so this file is evaluated more than once per boot.
unless Rails.application.config.assets.knapsack_paths_prepended
  Rails.application.config.assets.knapsack_paths_prepended = true

  Rails.application.config.assets.configure do |env|
    HykuKnapsack::Engine.root.glob('app/assets/*').select(&:directory?).reverse_each do |path|
      env.prepend_path(path.to_s)
    end
  end
end
