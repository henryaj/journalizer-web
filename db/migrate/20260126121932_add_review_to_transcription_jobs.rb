class AddReviewToTranscriptionJobs < ActiveRecord::Migration[8.0]
  def change
    # Add review fields to transcription_jobs
    add_column :transcription_jobs, :date_parsing_enabled, :boolean, default: true, null: false
    add_column :transcription_jobs, :reviewed_at, :datetime

    # Create page_groups table for manual image grouping
    create_table :page_groups do |t|
      t.references :transcription_job, null: false, foreign_key: true
      t.integer :group_number, null: false
      t.timestamps
    end

    add_index :page_groups, [:transcription_job_id, :group_number], unique: true

    # Link job_pages to page_groups
    add_reference :job_pages, :page_group, foreign_key: true
  end
end
