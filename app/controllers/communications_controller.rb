class CommunicationsController < ApplicationController
  before_action :authenticate_user!

  def index
    # Combined communication upload page for MBOX, LinkedIn messages, and Discord
  end

  def upload_mbox
    # Process uploaded MBOX files
    if params[:file].present?
      begin
        uploaded_file = params[:file]
        file_size = uploaded_file.size

        # For files larger than 50MB, process in background
        if file_size > 50.megabytes
          # Save the uploaded file to a temporary location
          temp_dir = Rails.root.join("tmp", "mbox_uploads")
          FileUtils.mkdir_p(temp_dir)

          temp_filename = "#{current_user.id}_#{Time.current.to_i}_#{uploaded_file.original_filename}"
          temp_path = temp_dir.join(temp_filename)

          # Copy uploaded file to temp location
          File.open(temp_path, "wb") do |file|
            file.write(uploaded_file.read)
          end

          # Queue background job
          MboxProcessingJob.perform_later(temp_path.to_s, current_user.id, uploaded_file.original_filename)

          redirect_to communications_path,
                      notice: "Large MBOX file (#{file_size / 1.megabyte}MB) queued for background processing. You'll be notified when complete."
        else
          # Process smaller files immediately
          result = MboxProcessor.new(uploaded_file, current_user).process

          message = "Successfully imported #{result[:count]} email messages."
          if result[:skipped] && result[:skipped] > 0
            message += " Skipped #{result[:skipped]} records"
            if result[:duplicates] && result[:duplicates] > 0
              message += " (#{result[:duplicates]} duplicates)"
            end
            message += "."
          end

          if result[:errors] && result[:errors].any?
            message += " Note: #{result[:errors].length} messages had processing errors."
          end

          redirect_to communications_path, notice: message
        end
      rescue => e
        redirect_to communications_path, alert: "Error processing MBOX file: #{e.message}"
      end
    else
      redirect_to communications_path, alert: "Please select an MBOX file to upload."
    end
  end

  def upload_linkedin_messages
    # Process uploaded LinkedIn messages CSV
    if params[:file].present?
      begin
        result = LinkedinMessagesProcessor.new(params[:file], current_user).process

        if result[:errors].any?
          error_message = "Errors occurred during import: #{result[:errors].join(', ')}"
          redirect_to communications_path, alert: error_message
        else
          message = "Successfully imported #{result[:imported]} LinkedIn messages."
          if result[:skipped] > 0
            message += " Skipped #{result[:skipped]} records"
            if result[:duplicates] > 0
              message += " (#{result[:duplicates]} duplicates)"
            end
            message += "."
          end
          redirect_to communications_path, notice: message
        end
      rescue => e
        redirect_to communications_path, alert: "Error processing LinkedIn messages file: #{e.message}"
      end
    else
      redirect_to communications_path, alert: "Please select a LinkedIn messages CSV file to upload."
    end
  end

  def view
    # Show imported communication records
    page = params[:page].to_i
    page = 1 if page < 1
    per_page = 50
    offset = (page - 1) * per_page

    # Determine which type of messages to show
    @message_type = params[:type] || 'email'

    if @message_type == 'linkedin'
      # LinkedIn messages
      linkedin_scope = current_user.linkedin_messages
      linkedin_scope = linkedin_scope.by_folder(params[:folder]) if params[:folder].present?

      @linkedin_messages = linkedin_scope.recent.limit(per_page).offset(offset)
      @total_count = linkedin_scope.count
    else
      # Email messages (default)
      @message_type = 'email'
      messages_scope = current_user.email_messages
      messages_scope = messages_scope.by_folder(params[:folder]) if params[:folder].present?

      @email_messages = messages_scope.recent.limit(per_page).offset(offset)
      @total_count = messages_scope.count
    end

    @current_page = page
    @total_pages = (@total_count.to_f / per_page).ceil
    @has_next = page < @total_pages
    @has_prev = page > 1
    @filtered_folder = params[:folder]

    # Statistics for both message types
    @total_email_messages = current_user.email_messages.count
    @total_linkedin_messages = current_user.linkedin_messages.count
    @total_size = current_user.email_messages.sum(:message_size)
    @total_messages = @message_type == 'linkedin' ? @total_linkedin_messages : @total_email_messages

    # Folders for current message type
    if @message_type == 'linkedin'
      @folders = current_user.linkedin_messages.group(:folder).count.sort_by { |folder, count| -count }
      @top_participants = current_user.linkedin_messages
                                     .group(:from_name)
                                     .order(Arel.sql("COUNT(*) DESC"))
                                     .limit(10)
                                     .count
      @date_range = {
        earliest: current_user.linkedin_messages.minimum(:sent_at),
        latest: current_user.linkedin_messages.maximum(:sent_at)
      }
    else
      @folders = current_user.email_messages.group(:folder).count.sort_by { |folder, count| -count }
      @top_senders = current_user.email_messages
                                 .group(:sender_email)
                                 .order(Arel.sql("COUNT(*) DESC"))
                                 .limit(10)
                                 .count
      @date_range = {
        earliest: current_user.email_messages.minimum(:received_date),
        latest: current_user.email_messages.maximum(:received_date)
      }
    end
  end

  def show
    # Show individual email message
    @email_message = current_user.email_messages.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to view_communications_path, alert: "Email message not found."
  end

  def clear
    # Clear all communication records for the current user
    count = current_user.email_messages.count
    current_user.email_messages.destroy_all
    redirect_to communications_path, notice: "Successfully deleted #{count} email messages."
  end
end
