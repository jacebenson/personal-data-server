class HealthAllergy < ApplicationRecord
  belongs_to :health_patient

  validates :allergen, presence: true
  validates :allergen, uniqueness: { scope: :health_patient_id }

  scope :active, -> { where(status: 'active') }
  scope :by_severity, ->(severity) { where(severity: severity) }

  def display_name
    reaction.present? ? "#{allergen} (#{reaction})" : allergen
  end

  def severity_color
    case severity&.downcase
    when 'high', 'severe'
      'red'
    when 'moderate', 'medium'
      'orange'
    when 'low', 'mild'
      'yellow'
    else
      'gray'
    end
  end
end
