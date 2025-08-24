class SocialSecurityProcessor
  attr_reader :user, :file_path, :errors

  def initialize(user, file_path)
    @user = user
    @file_path = file_path
    @errors = []
  end

  def process
    return false unless validate_file

    earnings_imported = 0

    begin
      doc = Nokogiri::XML(File.open(@file_path))

      # Find all earnings records in the XML
      earnings_records = doc.xpath("//osss:Earnings", "osss" => "http://ssa.gov/osss/schemas/2.0")

      Rails.logger.info "Found #{earnings_records.length} earnings records to process"

      earnings_records.each do |record|
        year = record["startYear"]&.to_i
        next unless year

        fica_earnings = record.at_xpath("osss:FicaEarnings", "osss" => "http://ssa.gov/osss/schemas/2.0")&.text&.to_f
        medicare_earnings = record.at_xpath("osss:MedicareEarnings", "osss" => "http://ssa.gov/osss/schemas/2.0")&.text&.to_f

        next unless fica_earnings && medicare_earnings

        # Check if this year already exists for this user
        existing_record = @user.social_security_earnings.find_by(year: year)

        if existing_record
          Rails.logger.info "Year #{year} already exists, skipping"
          next
        end

        # Create new Social Security earning record
        earning = @user.social_security_earnings.build(
          year: year,
          fica_earnings: fica_earnings,
          medicare_earnings: medicare_earnings
        )

        if earning.save
          earnings_imported += 1
          Rails.logger.info "Imported earnings for year #{year}: FICA $#{fica_earnings}, Medicare $#{medicare_earnings}"
        else
          @errors << "Failed to save earnings for year #{year}: #{earning.errors.full_messages.join(', ')}"
        end
      end

    rescue Nokogiri::XML::SyntaxError => e
      @errors << "XML parsing error: #{e.message}"
      return false
    rescue StandardError => e
      @errors << "Unexpected error: #{e.message}"
      Rails.logger.error "Social Security processing error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      return false
    end

    earnings_imported > 0
  end

  def import_count
    @import_count ||= 0
  end

  private

  def validate_file
    unless File.exist?(@file_path)
      @errors << "File not found: #{@file_path}"
      return false
    end

    unless File.readable?(@file_path)
      @errors << "File is not readable: #{@file_path}"
      return false
    end

    # Basic check that it contains Social Security XML data
    content = File.read(@file_path, 1000) # Read first 1000 chars
    unless content.include?("osss:OnlineSocialSecurityStatementData") || content.include?("osss:EarningsRecord")
      @errors << "File does not appear to be a valid Social Security XML export"
      return false
    end

    true
  end
end
