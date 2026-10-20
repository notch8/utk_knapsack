# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'UTK Digital Collection stylesheet' do
  let(:stylesheet) { HykuKnapsack::Engine.root.join('app/assets/stylesheets/hyku_knapsack/utk_digital_collection.scss').read }
  let(:hyku_theme) do
    sources = Rails.root.glob('app/assets/stylesheets/themes/digital_collection{,_show,/*}.scss')
    sources << Rails.root.join('app', 'views', 'shared', '_appearance_styles.html.erb')
    sources.map(&:read).join("\n")
  end

  it "sets only settings Hyku's Digital Collection theme reads" do
    settings = stylesheet.scan(/(--dc-[\w-]+)\s*:/).flatten

    expect(settings).not_to be_empty
    expect(settings.reject { |name| hyku_theme.match?(/var\(#{Regexp.escape(name)}(?![\w-])/) }).to be_empty
  end

  let(:knapsack_theme_views) { HykuKnapsack::Engine.root.glob('app/views/themes/**/*.erb').map(&:read).join("\n") }

  it "styles only Digital Collection elements Hyku's theme or the knapsack's theme views still have" do
    classes = stylesheet.scan(/\.(dc-[\w-]+)/).flatten.uniq
    missing = classes.reject do |name|
      hyku_theme.match?(/\.#{Regexp.escape(name)}(?![\w-])/) ||
        knapsack_theme_views.match?(/class="[^"]*(?<![\w-])#{Regexp.escape(name)}(?![\w-])/)
    end

    expect(classes).not_to be_empty
    expect(missing).to be_empty
  end
end
