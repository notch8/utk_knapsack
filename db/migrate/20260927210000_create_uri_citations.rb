# frozen_string_literal: true

class CreateUriCitations < ActiveRecord::Migration[7.0]
  def change
    create_table :uri_citations do |t|
      t.string :tenant, null: false
      t.string :work_id, null: false
      t.text :uri, null: false
      t.timestamps
    end

    add_index :uri_citations, %i[tenant work_id uri], unique: true
  end
end
