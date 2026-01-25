class AddOrientationToJobPages < ActiveRecord::Migration[8.1]
  def change
    add_column :job_pages, :orientation, :integer
  end
end
