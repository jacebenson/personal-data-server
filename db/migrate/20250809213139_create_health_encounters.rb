class CreateHealthEncounters < ActiveRecord::Migration[8.0]
  def change
    create_table :health_encounters do |t|
      t.references :health_patient, null: false, foreign_key: true
      t.string :encounter_date
      t.string :encounter_type
      t.text :reason_for_visit
      t.string :provider_name
      t.string :provider_specialty
      t.string :facility_name
      t.string :encounter_status
      t.text :diagnosis

      t.timestamps
    end
  end
end
