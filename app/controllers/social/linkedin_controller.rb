class Social::LinkedinController < Social::BaseController
  def index
    # Main LinkedIn page - shows upload form and statistics
    @total_messages = current_user.linkedin_messages.count
    @total_conversations = current_user.linkedin_messages.distinct.count(:conversation_id)
    @recent_messages = current_user.linkedin_messages.recent.limit(5)
    @date_range = {
      earliest: current_user.linkedin_messages.minimum(:sent_at),
      latest: current_user.linkedin_messages.maximum(:sent_at)
    }
  end

  def show
    # Show individual LinkedIn message
    @linkedin_message = current_user.linkedin_messages.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to social_linkedin_messages_path, alert: "LinkedIn message not found."
  end
end
