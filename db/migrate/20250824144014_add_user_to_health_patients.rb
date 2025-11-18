class AddUserToHealthPatients < ActiveRecord::Migration[8.0]
  def change
    add_reference :health_patients, :user, null: false, foreign_key: true
  end
end
