class HealthPatient < ApplicationRecord
  has_many :health_allergies, dependent: :destroy
  has_many :health_medications, dependent: :destroy
  has_many :health_problems, dependent: :destroy
  has_many :health_immunizations, dependent: :destroy
  has_many :health_vital_signs, dependent: :destroy
  has_many :health_encounters, dependent: :destroy
  has_many :health_sleep_data, dependent: :destroy, class_name: 'HealthSleepData'

  validates :first_name, presence: true
  validates :last_name, presence: true

  def full_name
    "#{first_name} #{last_name}".strip
  end

  def formatted_birth_date
    return nil unless birth_date
    Date.parse(birth_date).strftime("%B %d, %Y") rescue birth_date
  end

  def age
    return nil unless birth_date
    birth_year = Date.parse(birth_date).year rescue nil
    return nil unless birth_year
    Date.current.year - birth_year
  end
end
