# frozen_string_literal: true
HykuKnapsack::Engine.routes.draw do
  get '/check-iiif', to: 'iiif#show', as: :iiif
  get '/dashboard/uri_lookup_failures', to: 'uri_lookup_failures#index', as: :uri_lookup_failures,
                                        constraints: { format: /html|csv/ }
end
