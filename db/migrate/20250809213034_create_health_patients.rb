class CreateHealthPatients < ActiveRecord::Migration[8.0]
  def change
    create_table :health_patients do |t|
      t.string :first_name
      t.string :last_name
      t.string :birth_date
      t.string :gender
      t.text :address
      t.string :phone
      t.string :email

      t.timestamps
    end
  end
end
