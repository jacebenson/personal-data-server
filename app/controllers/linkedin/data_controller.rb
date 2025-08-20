class Linkedin::DataController < Linkedin::BaseController
  def upload
    # Process uploaded LinkedIn messages CSV
    if params[:file].present?
      begin
        result = LinkedinMessagesProcessor.new(params[:file], current_user).process

        if result[:errors].any?
          error_message = "Errors occurred during import: #{result[:errors].join(', ')}"
          redirect_to linkedin_index_path, alert: error_message
        else
          message = "Successfully imported #{result[:imported]} LinkedIn messages."
          if result[:skipped] > 0
            message += " Skipped #{result[:skipped]} records"
            if result[:duplicates] > 0
              message += " (#{result[:duplicates]} duplicates)"
            end
            message += "."
          end
          redirect_to linkedin_index_path, notice: message
        end
      rescue => e
        redirect_to linkedin_index_path, alert: "Error processing LinkedIn messages file: #{e.message}"
      end
    else
      redirect_to linkedin_index_path, alert: "Please select a LinkedIn messages CSV file to upload."
    end
  end

  def clear
    # Clear all LinkedIn messages for the current user
    count = current_user.linkedin_messages.count
    current_user.linkedin_messages.destroy_all
    redirect_to linkedin_index_path, notice: "Successfully deleted #{count} LinkedIn messages."
  end
end
