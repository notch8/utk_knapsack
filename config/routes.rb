# frozen_string_literal: true
HykuKnapsack::Engine.routes.draw do
  get '/check-iiif', to: 'iiif#show', as: :iiif
end
