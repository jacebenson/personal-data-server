class CreateHealthProblems < ActiveRecord::Migration[8.0]
  def change
    create_table :health_problems do |t|
      t.references :health_patient, null: false, foreign_key: true
      t.string :problem_name
      t.string :code
      t.string :code_system
      t.string :status
      t.string :onset_date
      t.string :resolved_date

      t.timestamps
    end

    add_index :health_problems, [:health_patient_id, :problem_name, :code, :onset_date],
              unique: true, name: 'index_health_problems_unique'
  end
end
