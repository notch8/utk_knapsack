# frozen_string_literal: true

ActionDispatch::Http::URL.secure_protocol = true if Rails.env.development?
