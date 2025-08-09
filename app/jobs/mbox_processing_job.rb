require 'tempfile'
require 'ostruct'

class MboxProcessingJob < ApplicationJob
  queue_as :default

  def perform(file_path, user_id, original_filename)
    user = User.find(user_id)
    
    # Create a temporary file object that mimics the uploaded file
    temp_file = Tempfile.new(['mbox_upload', '.mbox'])
    temp_file.binmode
    
    begin
      # Copy the uploaded file content to temp file
      File.open(file_path, 'rb') do |source|
        IO.copy_stream(source, temp_file)
      end
      
      temp_file.rewind
      
      # Create a file object that mimics ActionDispatch::Http::UploadedFile
      file_object = OpenStruct.new(
        path: temp_file.path,
        original_filename: original_filename
      )
      
      # Process the MBOX file
      result = MboxProcessor.new(file_object, user).process
      
      # Log the results
      Rails.logger.info "MBOX processing completed for user #{user_id}: #{result[:count]} messages imported"
      
      # TODO: Send notification to user about completion
      # You could use ActionCable, email, or in-app notifications here
      
    rescue => e
      Rails.logger.error "MBOX processing failed for user #{user_id}: #{e.message}"
      # TODO: Send error notification to user
    ensure
      # Clean up temporary file
      temp_file.close
      temp_file.unlink
      
      # Clean up original uploaded file
      File.delete(file_path) if File.exist?(file_path)
    end
  end
end
