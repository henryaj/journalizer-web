class CreateJournalEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :journal_entries do |t|
      t.references :user, null: false, foreign_key: true
      t.references :transcription_job, foreign_key: true  # nullable for manual entries
      t.date :entry_date, null: false
      t.text :content, null: false
      t.boolean :date_detected, default: false
      t.string :source, default: "handwritten-ocr"
      t.jsonb :image_indices, default: []
      t.boolean :synced, default: false
      t.datetime :expires_at

      t.timestamps
    end
    add_index :journal_entries, [:user_id, :entry_date]
    add_index :journal_entries, [:user_id, :synced]
    add_index :journal_entries, :expires_at
  end
end
