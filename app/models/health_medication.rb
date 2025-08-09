class HealthMedication < ApplicationRecord
  belongs_to :health_patient

  validates :medication_name, presence: true
  validates :medication_name, uniqueness: {
    scope: [:health_patient_id, :dosage, :start_date]
  }

  scope :active, -> { where(status: 'active') }
  scope :current, -> { active.where('end_date IS NULL OR end_date > ?', Date.current) }
  scope :historical, -> { where('end_date IS NOT NULL AND end_date <= ?', Date.current) }

  def display_name
    name = medication_name
    name += " #{dosage}" if dosage.present?
    name += " (#{frequency})" if frequency.present?
    name
  end

  def current?
    status == 'active' && (end_date.nil? || end_date > Date.current)
  end

  def duration_text
    return "Current" if current?
    return "Started #{formatted_start_date}" if start_date.present? && end_date.blank?
    return "#{formatted_start_date} - #{formatted_end_date}" if start_date.present? && end_date.present?
    "Unknown duration"
  end

  private

  def formatted_start_date
    return nil unless start_date
    Date.parse(start_date).strftime("%m/%d/%Y") rescue start_date
  end

  def formatted_end_date
    return nil unless end_date
    Date.parse(end_date).strftime("%m/%d/%Y") rescue end_date
  end
end
