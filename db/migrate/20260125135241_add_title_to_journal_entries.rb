class AddTitleToJournalEntries < ActiveRecord::Migration[8.1]
  def change
    add_column :journal_entries, :title, :string
    change_column_null :journal_entries, :entry_date, true
  end
end
