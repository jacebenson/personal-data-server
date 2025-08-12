class Api::V1::OverviewController < Api::V1::BaseController
  def index
    render_success({
      health: recent_and_active_health,
      communications: recent_communications, 
      transactions: recent_amazon_transactions,
      last_updated: most_recent_update
    })
  end

  private

  def recent_and_active_health
    patient = HealthPatient.first
    return {} unless patient

    {
      patient: {
        name: patient.full_name,
        age: patient.age,
        gender: patient.gender
      },
      active_allergies: patient.health_allergies.where(status: 'active').order(allergen: :desc).limit(10).map do |allergy|
        {
          allergen: allergy.allergen,
          reaction: allergy.reaction,
          severity: allergy.severity
        }
      end,
      active_medications: patient.health_medications.where(status: 'active').order(medication_name: :desc).limit(10).map do |med|
        {
          name: med.medication_name,
          dosage: med.dosage,
          frequency: med.frequency
        }
      end,
      active_problems: patient.health_problems.where(status: 'active').order(problem_name: :desc).limit(10).map do |problem|
        {
          name: problem.problem_name,
          severity: problem.severity,
          onset_date: problem.onset_date
        }
      end,
      recent_encounters: patient.health_encounters.order(encounter_date: :desc).limit(5).map do |encounter|
        {
          date: encounter.encounter_date,
          type: encounter.encounter_type,
          provider: encounter.provider_name,
          facility: encounter.facility_name
        }
      end
    }
  end

  def recent_communications
    {
      emails: current_user.email_messages.order(received_date: :desc).limit(10).map do |email|
        {
          date: email.received_date,
          from: email.sender_email,
          subject: email.subject&.truncate(80)
        }
      end,
      linkedin: current_user.linkedin_messages.order(sent_at: :desc).limit(10).map do |message|
        {
          date: message.sent_at,
          from: message.from_name,
          subject: message.subject&.truncate(80)
        }
      end
    }
  end

  def recent_amazon_transactions
    current_user.amazon_orders.order(order_date: :desc).limit(15).map do |order|
      {
        date: order.order_date,
        item: order.item_name&.truncate(60),
        amount: order.item_total,
        status: order.order_status
      }
    end
  end

  def most_recent_update
    updates = [
      HealthPatient.maximum(:updated_at),
      current_user.email_messages.maximum(:updated_at),
      current_user.linkedin_messages.maximum(:updated_at),
      current_user.amazon_orders.maximum(:updated_at)
    ].compact
    
    updates.max
  end
end
