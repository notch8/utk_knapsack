# frozen_string_literal: true
# see https://github.com/kbrock/bundler-inject/tree/gem_path

# specify one or more ruby files in this directory to be injected into bundler
# you can use `gem` to add new gems, `override_gem` to change an existing gem
# or `ensure_gem` to make sure a gem is there w/o worrying about if it is an
# override or not
override_gem "bulkrax", github: "samvera/bulkrax", branch: "9-stable"
# 3.2 builds a flexible record's manifest metadata from its profile (hyrax-webapp's ~> 3.1 locks 3.1.1)
override_gem "iiif_print", "~> 3.2"
override_gem "rails", ">= 7.2.3.2"
