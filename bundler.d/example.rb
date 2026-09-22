# frozen_string_literal: true
# see https://github.com/kbrock/bundler-inject/tree/gem_path

# specify one or more ruby files in this directory to be injected into bundler
# you can use `gem` to add new gems, `override_gem` to change an existing gem
# or `ensure_gem` to make sure a gem is there w/o worrying about if it is an
# override or not
override_gem "bulkrax", github: "samvera/bulkrax", branch: "9-stable"
# ExternalIiifDisplayImagePresenter isn't defined until 3.1.1 (hyrax-webapp's ~> 3.1 resolves to 3.1.0)
override_gem "iiif_print", "~> 3.1.1"
