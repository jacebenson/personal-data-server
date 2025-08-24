class HealthVitalSign < ApplicationRecord
  belongs_to :health_patient

  validates :measurement_date, presence: true

  scope :recent, -> { where('measurement_date > ?', 1.year.ago) }
  scope :by_date_range, ->(start_date, end_date) { where(measurement_date: start_date..end_date) }

  def formatted_date
    return nil unless measurement_date.present?
    Date.parse(measurement_date).strftime("%m/%d/%Y") rescue measurement_date
  end

  def blood_pressure
    return nil unless systolic_bp.present? && diastolic_bp.present?
    "#{systolic_bp}/#{diastolic_bp}"
  end

  def bp_category
    return nil unless systolic_bp.present? && diastolic_bp.present?

    if systolic_bp < 120 && diastolic_bp < 80
      'Normal'
    elsif systolic_bp < 130 && diastolic_bp < 80
      'Elevated'
    elsif systolic_bp < 140 || diastolic_bp < 90
      'High Blood Pressure Stage 1'
    elsif systolic_bp < 180 || diastolic_bp < 120
      'High Blood Pressure Stage 2'
    else
      'Hypertensive Crisis'
    end
  end

  def bmi_category
    return nil unless bmi.present?

    if bmi < 18.5
      'Underweight'
    elsif bmi < 25
      'Normal weight'
    elsif bmi < 30
      'Overweight'
    else
      'Obese'
    end
  end

  def temperature_f
    return nil unless temperature.present?
    # Assuming temperature is in Celsius, convert to Fahrenheit
    (temperature * 9.0 / 5.0) + 32
  end

  def weight_lbs
    return nil unless weight.present?
    # Convert kg to lbs
    (weight * 2.20462).round(1)
  end

  def weight_display
    return '-' unless weight.present?
    "#{weight_lbs} lbs"
  end

  def weight_with_hover
    return '-' unless weight.present?
    "<span title=\"#{weight.round(1)} kg\" class=\"cursor-help\">#{weight_lbs} lbs</span>".html_safe
  end

  def has_vitals?
    [height, weight, bmi, systolic_bp, diastolic_bp, heart_rate,
     temperature, respiratory_rate, oxygen_saturation].any?(&:present?)
  end
end
