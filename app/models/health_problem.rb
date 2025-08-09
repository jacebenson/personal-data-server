class HealthProblem < ApplicationRecord
  belongs_to :health_patient

  validates :problem_name, presence: true
  validates :problem_name, uniqueness: {
    scope: [:health_patient_id, :code, :onset_date]
  }

  scope :active, -> { where(status: 'active') }
  scope :resolved, -> { where(status: 'resolved') }
  scope :chronic, -> { active.where('onset_date IS NOT NULL AND onset_date < ?', 1.year.ago) }

  def display_name
    problem_name
  end

  def active?
    status == 'active' && (resolved_date.nil? || resolved_date > Date.current)
  end

  def duration_text
    return "Resolved" unless active?
    return "Since #{formatted_onset_date}" if onset_date.present?
    "Unknown onset"
  end

  def severity_indicator
    # Could be enhanced with more sophisticated logic
    case problem_name&.downcase
    when /cancer|tumor|malign/
      'high'
    when /diabetes|hypertension|heart/
      'medium'
    else
      'low'
    end
  end

  private

  def formatted_onset_date
    return nil unless onset_date
    Date.parse(onset_date).strftime("%m/%d/%Y") rescue onset_date
  end
end
