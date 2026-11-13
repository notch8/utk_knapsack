# frozen_string_literal: true
# see https://github.com/kbrock/bundler-inject/tree/gem_path

# specify one or more ruby files in this directory to be injected into bundler
# you can use `gem` to add new gems, `override_gem` to change an existing gem
# or `ensure_gem` to make sure a gem is there w/o worrying about if it is an
# override or not
# OVERRIDE Bulkrax (1bd53d2f), backporting (acc18e4): picks up the same
# dependency fix Hyku v7.2.2 ships (via Bulkrax v9.5.2, a different branch's
# release of the same fix). Pin can move again once hyrax-webapp vendors a
# bulkrax release past this commit.
override_gem "bulkrax", github: "samvera/bulkrax", ref: "acc18e45a95e05d9f3c030ddef0a84a71a8d5975"
# 3.2 builds a flexible record's manifest metadata from its profile (hyrax-webapp's ~> 3.1 locks 3.1.1)
override_gem "iiif_print", "~> 3.3.0"
override_gem "rails", ">= 7.2.3.2"
