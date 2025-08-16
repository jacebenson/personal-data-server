class HealthSleepData < ApplicationRecord
  belongs_to :health_patient

  validates :session_date, presence: true
  validates :session_date, uniqueness: { scope: [:health_patient_id, :device_serial] }

  scope :recent, -> { where('session_date > ?', 3.months.ago) }
  scope :by_date_range, ->(start_date, end_date) { where(session_date: start_date..end_date) }
  scope :good_compliance, -> { where('usage_hours >= ?', 4.0) }

  def formatted_date
    return nil unless session_date.present?
    Date.parse(session_date).strftime("%m/%d/%Y") rescue session_date
  end

  def compliance_status
    return 'Unknown' unless usage_hours.present?
    
    if usage_hours >= 4.0
      'Compliant'
    elsif usage_hours >= 2.0
      'Partial'
    else
      'Non-compliant'
    end
  end

  def compliance_percentage
    return 0 unless usage_hours.present?
    # Assuming 8 hours is target sleep
    [(usage_hours / 8.0 * 100).round(1), 100].min
  end

  def ahi_severity
    return 'Unknown' unless ahi.present?
    
    if ahi < 5
      'Normal'
    elsif ahi < 15
      'Mild'
    elsif ahi < 30
      'Moderate'
    else
      'Severe'
    end
  end

  def sleep_quality_indicator
    return 'Unknown' unless sleep_score.present?
    
    if sleep_score >= 80
      'Excellent'
    elsif sleep_score >= 60
      'Good'
    elsif sleep_score >= 40
      'Fair'
    else
      'Poor'
    end
  end

  def usage_hours_display
    return '-' unless usage_hours.present?
    hours = usage_hours.to_i
    minutes = ((usage_hours % 1) * 60).round
    "#{hours}h #{minutes}m"
  end

  def leak_status
    return 'Unknown' unless leak_score.present?
    
    case leak_score
    when 80..100
      'Excellent'
    when 60..79
      'Good'
    when 40..59
      'Fair'
    when 20..39
      'Poor'
    else
      'Very Poor'
    end
  end

  def mask_fit_status
    return 'Unknown' unless mask_score.present?
    
    case mask_score
    when 80..100
      'Excellent Seal'
    when 60..79
      'Good Seal'
    when 40..59
      'Fair Seal'
    when 20..39
      'Poor Seal'
    else
      'Very Poor Seal'
    end
  end

  def overall_therapy_effectiveness
    return 'Unknown' unless usage_hours.present? && ahi.present? && sleep_score.present?
    
    # Weighted scoring: compliance (40%), AHI improvement (30%), sleep quality (30%)
    compliance_points = usage_hours >= 4.0 ? 40 : (usage_hours / 4.0 * 40)
    ahi_points = ahi < 5 ? 30 : (ahi < 15 ? 20 : (ahi < 30 ? 10 : 0))
    quality_points = (sleep_score / 100.0 * 30)
    
    total_score = compliance_points + ahi_points + quality_points
    
    if total_score >= 80
      'Excellent'
    elsif total_score >= 60
      'Good'
    elsif total_score >= 40
      'Fair'
    else
      'Needs Improvement'
    end
  end
end
