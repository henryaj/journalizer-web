class AddYearHintToTranscriptionJobs < ActiveRecord::Migration[8.1]
  def change
    add_column :transcription_jobs, :year_hint, :integer
  end
end
