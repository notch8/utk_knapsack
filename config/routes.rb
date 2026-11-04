# frozen_string_literal: true
HykuKnapsack::Engine.routes.draw do
  get '/check-iiif', to: 'iiif#show', as: :iiif
  get '/concern/images/*rest', to: redirect(path: '/concern/still_images/%{rest}'), format: false
  get '/concern/parent/:parent_id/images/*rest',
      to: redirect(path: '/concern/parent/%{parent_id}/still_images/%{rest}'),
      format: false
end
