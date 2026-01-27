class AddUserJobNumberToTranscriptionJobs < ActiveRecord::Migration[8.1]
  def up
    add_column :transcription_jobs, :user_job_number, :integer

    # Backfill existing jobs with sequential numbers per user
    execute <<-SQL
      WITH numbered_jobs AS (
        SELECT id, ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY created_at) as job_num
        FROM transcription_jobs
      )
      UPDATE transcription_jobs
      SET user_job_number = numbered_jobs.job_num
      FROM numbered_jobs
      WHERE transcription_jobs.id = numbered_jobs.id
    SQL

    change_column_null :transcription_jobs, :user_job_number, false
    add_index :transcription_jobs, [:user_id, :user_job_number], unique: true
  end

  def down
    remove_index :transcription_jobs, [:user_id, :user_job_number]
    remove_column :transcription_jobs, :user_job_number
  end
end
