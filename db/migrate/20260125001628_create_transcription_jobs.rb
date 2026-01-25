class CreateTranscriptionJobs < ActiveRecord::Migration[8.1]
  def change
    create_table :transcription_jobs do |t|
      t.references :user, null: false, foreign_key: true
      t.string :status, null: false, default: "pending"
      t.integer :page_count, null: false, default: 0
      t.integer :credits_charged, default: 0
      t.text :error_message
      t.datetime :started_at
      t.datetime :completed_at
      t.datetime :expires_at

      t.timestamps
    end
    add_index :transcription_jobs, [:user_id, :status]
    add_index :transcription_jobs, [:status, :created_at]
    add_index :transcription_jobs, :expires_at
  end
end
