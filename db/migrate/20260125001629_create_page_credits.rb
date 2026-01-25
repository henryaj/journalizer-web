class CreatePageCredits < ActiveRecord::Migration[8.1]
  def change
    create_table :page_credits do |t|
      t.references :user, null: false, foreign_key: true
      t.string :transaction_type, null: false
      t.integer :amount, null: false
      t.integer :balance_after, null: false
      t.string :stripe_payment_intent_id
      t.references :transcription_job, foreign_key: true  # nullable - purchases don't have a job

      t.timestamps
    end
    add_index :page_credits, [:user_id, :created_at]
    add_index :page_credits, :stripe_payment_intent_id, unique: true
  end
end
