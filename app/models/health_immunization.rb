class HealthImmunization < ApplicationRecord
  belongs_to :health_patient

  validates :vaccine_name, presence: true

  scope :recent, -> { where('administration_date > ?', 5.years.ago) }
  scope :by_vaccine, ->(vaccine) { where('vaccine_name ILIKE ?', "%#{vaccine}%") }

  def display_name
    vaccine_name
  end

  def formatted_date
    return nil unless administration_date.present?
    Date.parse(administration_date).strftime("%m/%d/%Y") rescue administration_date
  end

  def due_for_booster?
    # Simple logic - could be enhanced with vaccine-specific intervals
    return false unless administration_date.present?

    begin
      admin_date = Date.parse(administration_date)
      case vaccine_name&.downcase
      when /tetanus|tdap/
        admin_date < 10.years.ago
      when /flu|influenza/
        admin_date < 1.year.ago
      when /covid/
        admin_date < 6.months.ago
      else
        false
      end
    rescue
      false
    end
  end

  def vaccine_type
    name = vaccine_name&.downcase || ""
    case name
    when /flu|influenza/
      'Influenza'
    when /covid|corona|pfizer|moderna|johnson/
      'COVID-19'
    when /tetanus|tdap/
      'Tetanus'
    when /hepatitis/
      'Hepatitis'
    when /mmr|measles|mumps|rubella/
      'MMR'
    else
      'Other'
    end
  end
end
