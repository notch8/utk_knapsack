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

# The file manager's sequence sort loads on its own, not through the host app's
# `application.js` manifest, so sprockets has to be told to build it. `|=` keeps
# a single entry across the repeated evaluation above.
Rails.application.config.assets.precompile |= ['hyku_knapsack/file_manager_sequence_sort.js']
