class HealthImportJob < ApplicationJob
  queue_as :default

  def perform(xml_file_path)
    Rails.logger.info "Starting health import job for: #{xml_file_path}"

    import_service = HealthImportService.new
    success = import_service.import_from_xml(xml_file_path)

    if success
      Rails.logger.info "Health import completed successfully"
      Rails.logger.info "Summary: #{import_service.summary}"
    else
      Rails.logger.error "Health import failed"
      Rails.logger.error "Errors: #{import_service.errors.join(', ')}"
      raise StandardError, "Health import failed: #{import_service.errors.join(', ')}"
    end

    import_service.summary
  end
end
