class Linkedin::ConversationsController < Linkedin::BaseController
  def index
    # Show conversations grouped view
    @conversations = current_user.linkedin_messages
                                .group(:conversation_id, :conversation_title)
                                .order('MAX(sent_at) DESC')
                                .limit(50)
                                .pluck(
                                  :conversation_id, 
                                  :conversation_title, 
                                  'COUNT(*) as message_count',
                                  'MAX(sent_at) as last_message_at'
                                )
  end

  def show
    # Show messages in a specific conversation
    @conversation_id = params[:id] || params[:conversation_id]
    @conversation_messages = current_user.linkedin_messages
                                        .where(conversation_id: @conversation_id)
                                        .order(:sent_at)
    
    @conversation_title = @conversation_messages.first&.conversation_title || "Unknown Conversation"
    
    # Extract participants from from_name and to_name fields
    participants = []
    @conversation_messages.each do |message|
      # Handle pipe-separated names in from_name and to_name
      if message.from_name.present?
        from_names = message.from_name.split('|').map(&:strip)
        participants.concat(from_names)
      end
      
      if message.to_name.present?
        to_names = message.to_name.split('|').flat_map { |names| names.split(',').map(&:strip) }
        participants.concat(to_names)
      end
    end
    
    @participants = participants.uniq.compact.reject(&:blank?)
  end
end
