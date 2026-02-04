class AddEmailPreferenceToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :email_preference, :string, default: "none", null: false
  end
end
