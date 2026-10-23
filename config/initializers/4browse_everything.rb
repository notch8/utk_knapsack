# frozen_string_literal: true

s3 = { bucket: ENV['BROWSE_EVERYTHING_S3_BUCKET'], region: ENV['BROWSE_EVERYTHING_S3_REGION'] }
keys = { app_key: ENV['BROWSE_EVERYTHING_S3_ACCESS_KEY_ID'], app_secret: ENV['BROWSE_EVERYTHING_S3_SECRET_ACCESS_KEY'] }
s3.merge!(keys) if keys.values.all?(&:present?)

BrowseEverything.configure(s3.values_at(:bucket, :region).all?(&:present?) ? { s3: } : {})
