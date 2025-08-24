class CreateHealthVitalSigns < ActiveRecord::Migration[8.0]
  def change
    create_table :health_vital_signs do |t|
      t.references :health_patient, null: false, foreign_key: true
      t.string :measurement_date
      t.decimal :height
      t.decimal :weight
      t.decimal :bmi
      t.integer :systolic_bp
      t.integer :diastolic_bp
      t.integer :heart_rate
      t.decimal :temperature
      t.integer :respiratory_rate
      t.decimal :oxygen_saturation

      t.timestamps
    end
  end
end
