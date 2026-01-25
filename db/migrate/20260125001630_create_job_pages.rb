class CreateJobPages < ActiveRecord::Migration[8.1]
  def change
    create_table :job_pages do |t|
      t.references :transcription_job, null: false, foreign_key: true
      t.integer :page_number, null: false
      t.string :status, null: false, default: "pending"
      t.string :handwriting_ocr_doc_id
      t.text :raw_ocr_text
      t.text :error_message

      t.timestamps
    end
    add_index :job_pages, [:transcription_job_id, :page_number], unique: true
    add_index :job_pages, :handwriting_ocr_doc_id
  end
end
