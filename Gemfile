# frozen_string_literal: true

source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

# Specify your gem's dependencies in hyku-knapsack.gemspec.
gemspec

# Start debugger with binding.b [https://github.com/ruby/debug]
# gem "debug", ">= 1.0.0"

gemfile_path = File.expand_path("hyrax-webapp/Gemfile", __dir__)
if File.exist?(gemfile_path)
  # Also drops hyrax-webapp's own iiif_print line (~> 3.1, resolves to 3.1.0 there) --
  # ExternalIiifDisplayImagePresenter isn't defined until 3.1.1, pinned below instead.
  gemfile = File.read(gemfile_path).split("\n").reject { |l| l.match('knapsack') || l.match(/gem ['"]iiif_print['"]/) }
  # rubocop:disable Security/Eval
  eval(gemfile.join("\n"), binding)
  # rubocop:enable Security/Eval
end

gem 'iiif_print', '~> 3.1.1'
