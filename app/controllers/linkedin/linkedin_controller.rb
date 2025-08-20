class Linkedin::LinkedinController < Linkedin::BaseController
  def index
    # Main LinkedIn page - shows upload form and statistics
    @total_messages = current_user.linkedin_messages.count
    @total_conversations = current_user.linkedin_messages.distinct.count(:conversation_id)
    @recent_messages = current_user.linkedin_messages.recent.limit(5)
    @date_range = {
      earliest: current_user.linkedin_messages.minimum(:sent_at),
      latest: current_user.linkedin_messages.maximum(:sent_at)
    }

    # Contact statistics derived from messages
    unique_contacts = current_user.linkedin_messages
                                  .pluck(:from_name, :to_name)
                                  .flatten
                                  .compact
                                  .uniq
    @total_contacts = unique_contacts.count
    @recent_contacts = current_user.linkedin_messages
                                   .recent
                                   .limit(10)
                                   .pluck(:from_name, :to_name)
                                   .flatten
                                   .compact
                                   .uniq
                                   .first(5)
  end
end
