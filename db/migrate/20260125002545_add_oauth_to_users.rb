class AddOauthToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :provider, :string
    add_column :users, :uid, :string
    add_column :users, :name, :string
    add_column :users, :avatar_url, :string

    # Make password_digest nullable for OAuth users
    change_column_null :users, :password_digest, true

    # Index for OAuth lookups
    add_index :users, [:provider, :uid], unique: true
  end
end
