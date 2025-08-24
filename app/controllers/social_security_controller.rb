class SocialSecurityController < ApplicationController
  before_action :authenticate_user!

  def index
    # Show Social Security earnings upload form
  end

  def upload_earnings
    # Process uploaded Social Security XML
    if params[:file].present?
      begin
        # Save the uploaded file temporarily
        temp_file = Rails.root.join("tmp", "uploads", "ssa_#{current_user.id}_#{Time.current.to_i}.xml")
        FileUtils.mkdir_p(File.dirname(temp_file))
        File.open(temp_file, "wb") do |file|
          file.write(params[:file].read)
        end

        processor = SocialSecurityProcessor.new(current_user, temp_file.to_s)
        result = processor.process

        if result
          imported_count = current_user.social_security_earnings.count
          message = "Successfully imported Social Security earnings data. Total records: #{imported_count}."
        else
          message = "No new earnings records were imported."
          if processor.errors.any?
            message += " Errors: #{processor.errors.join(', ')}"
          end
        end

        # Clean up temp file
        File.delete(temp_file) if File.exist?(temp_file)

        redirect_to social_security_index_path, notice: message
      rescue => e
        # Clean up temp file on error
        File.delete(temp_file) if defined?(temp_file) && File.exist?(temp_file)
        redirect_to social_security_index_path, alert: "Error processing file: #{e.message}"
      end
    else
      redirect_to social_security_index_path, alert: "Please select a file to upload."
    end
  end

  def view_earnings
    # Show imported Social Security earnings records
    @earnings = current_user.social_security_earnings.order(year: :desc)

    if @earnings.any?
      @total_fica = @earnings.sum(:fica_earnings)
      @total_medicare = @earnings.sum(:medicare_earnings)
      @years_covered = "#{current_user.social_security_earnings.minimum(:year)} - #{current_user.social_security_earnings.maximum(:year)}"
      @peak_year = @earnings.max_by(&:fica_earnings)
      @recent_avg = current_user.social_security_earnings.order(:year).last(5).sum(&:fica_earnings) / [ current_user.social_security_earnings.order(:year).last(5).count, 1 ].max
    end
  end

  def clear_earnings
    # Clear all Social Security earnings for the current user
    count = current_user.social_security_earnings.count
    current_user.social_security_earnings.destroy_all
    redirect_to social_security_index_path, notice: "Successfully deleted #{count} Social Security earnings records."
  end
end
