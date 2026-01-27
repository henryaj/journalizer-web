class AddEntryRetentionToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :entry_retention, :string, default: "days_30", null: false
  end
end
