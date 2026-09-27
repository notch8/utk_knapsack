# frozen_string_literal: true

class AddFailureTrackingToUriCaches < ActiveRecord::Migration[7.0]
  def up
    change_table :uri_caches, bulk: true do |t|
      t.string :status, null: false, default: 'resolved'
      t.text :reason
      t.boolean :permanent, null: false, default: false
      t.integer :attempts, null: false, default: 0
      t.datetime :retry_after
    end
    change_column_null :uri_caches, :value, true

    UriCache.reset_column_information
    UriCache.reclassify_legacy_failures!
  end

  def down
    execute 'DELETE FROM uri_caches WHERE value IS NULL'
    change_column_null :uri_caches, :value, false
    change_table :uri_caches, bulk: true do |t|
      t.remove :status, :reason, :permanent, :attempts, :retry_after
    end
  end
end
