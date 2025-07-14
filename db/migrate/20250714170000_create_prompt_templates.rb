# frozen_string_literal: true

class CreatePromptTemplates < ActiveRecord::Migration[8.0]
  def change
    create_table :prompt_templates do |t|
      t.string :name, null: false
      t.string :template_type, null: false
      t.text :content, null: false
      t.integer :version, null: false, default: 1
      t.text :description
      t.string :created_by
      t.boolean :is_active, null: false, default: false
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    # 인덱스 추가
    add_index :prompt_templates, [:name, :version], unique: true
    add_index :prompt_templates, [:template_type, :is_active]
    add_index :prompt_templates, :is_active
    add_index :prompt_templates, :metadata, using: :gin
  end
end