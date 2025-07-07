class EnablePgTrgmExtension < ActiveRecord::Migration[8.0]
  def change
    # Enable pg_trgm extension for full-text search
    enable_extension "pg_trgm"
  end
end
