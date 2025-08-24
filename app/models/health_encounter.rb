class HealthEncounter < ApplicationRecord
  belongs_to :health_patient

  validates :encounter_date, presence: true

  scope :recent, -> { where("encounter_date > ?", 1.year.ago) }
  scope :by_provider, ->(provider) { where("provider_name LIKE ? COLLATE NOCASE", "%#{provider}%") }
  scope :by_type, ->(type) { where("encounter_type LIKE ? COLLATE NOCASE", "%#{type}%") }

  def formatted_date
    return nil unless encounter_date.present?
    Date.parse(encounter_date).strftime("%m/%d/%Y") rescue encounter_date
  end

  def display_provider
    name = provider_name || "Unknown Provider"
    name += " (#{provider_specialty})" if provider_specialty.present?
    name
  end

  def display_type
    encounter_type.presence || "General Visit"
  end

  def location_info
    facility_name.presence || "Unknown Facility"
  end

  def summary
    parts = []
    parts << display_type
    parts << "with #{provider_name}" if provider_name.present?
    parts << "at #{facility_name}" if facility_name.present?
    parts.join(" ")
  end

  def visit_category
    type = encounter_type&.downcase || ""
    case type
    when /emergency|urgent|er/
      "Emergency"
    when /inpatient|hospital|admission/
      "Inpatient"
    when /outpatient|office|clinic/
      "Outpatient"
    when /telehealth|virtual|phone/
      "Telehealth"
    when /preventive|annual|physical|wellness/
      "Preventive"
    else
      "Other"
    end
  end
end
