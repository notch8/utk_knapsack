# frozen_string_literal: true

class CreateUriCaches < ActiveRecord::Migration[7.0]
  def change
    create_table :uri_caches do |t|
      t.text :uri, null: false
      t.text :value, null: false
      t.timestamps
    end

    add_index :uri_caches, :uri, unique: true
  end
end
