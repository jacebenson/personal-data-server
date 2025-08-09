class CreateHealthMedications < ActiveRecord::Migration[8.0]
  def change
    create_table :health_medications do |t|
      t.references :health_patient, null: false, foreign_key: true
      t.string :medication_name
      t.string :dosage
      t.string :frequency
      t.string :route
      t.string :start_date
      t.string :end_date
      t.string :status
      t.string :prescriber

      t.timestamps
    end

    add_index :health_medications, [:health_patient_id, :medication_name, :dosage, :start_date],
              unique: true, name: 'index_health_medications_unique'
  end
end
