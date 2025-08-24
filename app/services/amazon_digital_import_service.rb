require "tempfile"

class AmazonDigitalImportService
  def initialize(user, file)
    @user = user
    @file = file
  end

  def import
    # Save the uploaded file temporarily
    temp_file = Tempfile.new([ "amazon_digital_orders", ".csv" ])
    temp_file.binmode
    temp_file.write(@file.read)
    temp_file.close

    begin
      # Use the existing AmazonDataProcessor
      processor = AmazonDataProcessor.new(temp_file.path, @user, "digital")
      result = processor.process

      Rails.logger.info "Amazon digital orders import completed: #{result}"
      result
    ensure
      # Clean up the temporary file
      temp_file.unlink if temp_file
    end
  end
end
