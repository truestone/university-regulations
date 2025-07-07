class CreateAiSettings < ActiveRecord::Migration[8.0]
  def change
    create_table :ai_settings do |t|
      t.string :provider, null: false
      t.string :api_key
      t.string :model_id, null: false
      t.decimal :monthly_budget, precision: 10, scale: 2, default: 0.0
      t.decimal :usage_this_month, precision: 10, scale: 2, default: 0.0
      t.boolean :is_active, default: false, null: false
      t.datetime :last_used_at

      t.timestamps
    end
    
    add_index :ai_settings, :provider
    add_index :ai_settings, :is_active
    add_index :ai_settings, [:provider, :model_id], unique: true
  end
end
