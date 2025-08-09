class CreateHealthAllergies < ActiveRecord::Migration[8.0]
  def change
    create_table :health_allergies do |t|
      t.references :health_patient, null: false, foreign_key: true
      t.string :allergen
      t.string :reaction
      t.string :severity
      t.string :status
      t.string :onset_date

      t.timestamps
    end

    add_index :health_allergies, [:health_patient_id, :allergen], unique: true
  end
end
