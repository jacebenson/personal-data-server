class HealthMedication < ApplicationRecord
  belongs_to :health_patient

  validates :medication_name, presence: true
  validates :medication_name, uniqueness: {
    scope: [:health_patient_id, :dosage, :start_date]
  }

  scope :active, -> { where(status: 'active') }
  scope :current, -> { active.where('end_date IS NULL OR end_date > ?', Date.current) }
  scope :historical, -> { where('end_date IS NOT NULL AND end_date <= ?', Date.current) }
  scope :completed, -> { where(status: 'completed') }
  scope :missed, -> { where(status: 'missed') }
  scope :shotsy_injections, -> { where(status: ['completed', 'missed']) }

  def display_name
    name = medication_name
    name += " #{dosage}" if dosage.present?
    name += " (#{frequency})" if frequency.present?
    name
  end

  def current?
    status == 'active' && (end_date.nil? || end_date > Date.current)
  end

  def shotsy_injection?
    prescriber&.include?("Shotsy tracking") || frequency == "Single injection"
  end

  def status_priority
    # For sorting: active medications first, then completed, then missed
    case status
    when 'active' then 1
    when 'completed' then 2
    when 'missed' then 3
    else 4
    end
  end

  def duration_text
    return "Current" if current?
    return "Started #{formatted_start_date}" if start_date.present? && end_date.blank?
    return "#{formatted_start_date} - #{formatted_end_date}" if start_date.present? && end_date.present?
    "Unknown duration"
  end

  def formatted_start_date
    return nil unless start_date.present?
    parse_and_format_date(start_date)
  end

  def formatted_end_date
    return nil unless end_date.present?
    parse_and_format_date(end_date)
  end

  def parse_and_format_date(date_string)
    return date_string unless date_string.is_a?(String)
    
    # Handle different date formats
    begin
      # Try ISO format first (YYYY-MM-DD from Shotsy)
      if date_string.match?(/^\d{4}-\d{2}-\d{2}$/)
        Date.parse(date_string).strftime("%m/%d/%Y")
      # Try existing formats
      else
        Date.parse(date_string).strftime("%m/%d/%Y")
      end
    rescue Date::Error
      # If parsing fails, return original string
      date_string
    end
  end

  private
end
