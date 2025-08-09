class CreateHealthImmunizations < ActiveRecord::Migration[8.0]
  def change
    create_table :health_immunizations do |t|
      t.references :health_patient, null: false, foreign_key: true
      t.string :vaccine_name
      t.string :vaccine_code
      t.string :administration_date
      t.string :administrator
      t.string :lot_number
      t.string :site
      t.string :route

      t.timestamps
    end
  end
end
