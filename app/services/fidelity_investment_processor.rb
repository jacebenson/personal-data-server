class FidelityInvestmentProcessor
  def initialize(file, user)
    @file = file
    @user = user
    @imported_count = 0
    @skipped_count = 0
    @duplicate_count = 0
  end

  def process
    Rails.logger.info "Starting Fidelity CSV processing"
    Rails.logger.info "File path: #{@file.path}"

    # First, let's clean the CSV by removing empty lines from the beginning
    content = File.read(@file.path)
    lines = content.lines.map(&:chomp)

    # Remove empty lines from the beginning
    while lines.first && lines.first.strip.empty?
      lines.shift
    end

    # Find the header line (should be the first non-empty line)
    header_line_index = lines.find_index { |line| line.include?("Run Date") }

    if header_line_index.nil?
      Rails.logger.error "Could not find header line containing 'Run Date'"
      return { count: 0, skipped: 0, duplicates: 0 }
    end

    # Remove everything before the header line
    lines = lines[header_line_index..-1]

    # Write cleaned content to a temporary file
    require "tempfile"
    temp_file = Tempfile.new([ "cleaned_csv", ".csv" ])
    temp_file.write(lines.join("\n"))
    temp_file.close

    begin
      # Now parse the cleaned CSV
      csv_table = CSV.read(temp_file.path, headers: true)
      headers = csv_table.headers
      Rails.logger.info "Detected Headers: #{headers.inspect}"

      row_count = 0
      CSV.foreach(temp_file.path, headers: true) do |row|
        row_count += 1
        create_investment_transaction(row)
      end

      Rails.logger.info "Total rows processed: #{row_count}"
    ensure
      temp_file.unlink # Clean up temp file
    end

    Rails.logger.info "Finished processing. Imported #{@imported_count} records, skipped #{@skipped_count} duplicates."
    {
      count: @imported_count,
      skipped: @skipped_count,
      duplicates: @duplicate_count
    }
  end

  private

  def create_investment_transaction(row)
    # Map Fidelity CSV columns
    run_date = parse_date(row["Run Date"])
    account = row["Account"]&.strip&.gsub(/^"/, "")&.gsub(/"$/, "") # Remove quotes
    account_number = row["Account Number"]&.strip&.gsub(/^"/, "")&.gsub(/"$/, "")
    action = row["Action"]&.strip
    symbol = row["Symbol"]&.strip
    description = row["Description"]&.strip
    investment_type = row["Type"]&.strip
    quantity = parse_decimal(row["Quantity"])
    price = parse_decimal(row["Price ($)"])
    commission = parse_decimal(row["Commission ($)"])
    fees = parse_decimal(row["Fees ($)"])
    amount = parse_decimal(row["Amount ($)"])
    settlement_date = parse_date(row["Settlement Date"])

    # Combine account number and name for consistency with portfolio processor
    account_display = account_number.present? && account.present? ? "#{account_number} - #{account}" : (account || account_number || "Unknown Account")

    Rails.logger.info "Parsed data: date=#{run_date}, action=#{action}, amount=#{amount}, description=#{description}"

    # Skip rows with no action or amount
    if action.blank? || amount.nil? || amount == 0
      @skipped_count += 1
      return
    end

    # Check for duplicates (including account name)
    existing_transaction = @user.investments.find_by(
      date: run_date,
      amount: amount,
      description: description,
      account: account_display
    )

    if existing_transaction
      @duplicate_count += 1
      @skipped_count += 1
      return
    end

    # Create investment record
    investment = @user.investments.build(
      date: run_date,
      action: action,
      symbol: symbol,
      description: description,
      investment_type: investment_type,
      quantity: quantity,
      price: price,
      commission: commission,
      fees: fees,
      amount: amount,
      account: account_display,
      settlement_date: settlement_date
    )

    Rails.logger.info "About to save investment: #{investment.attributes.inspect}"

    if investment.save
      @imported_count += 1
    else
      @skipped_count += 1
      Rails.logger.error "Failed to save investment: #{investment.errors.full_messages}"
    end
  end

  def parse_date(date_string)
    return nil if date_string.blank?

    # Try different date formats for Fidelity
    [ "%m/%d/%Y" ].each do |format|
      begin
        return Date.strptime(date_string, format).beginning_of_day
      rescue ArgumentError
        next
      end
    end

    # Fallback to Date.parse
    begin
      Date.parse(date_string).beginning_of_day
    rescue ArgumentError
      nil
    end
  end

  def parse_decimal(amount_string)
    return nil if amount_string.blank?

    # Remove currency symbols and commas, handle parentheses for negative values
    cleaned = amount_string.to_s.gsub(/[\$,]/, "").strip

    # Handle negative values in parentheses
    if cleaned.match(/^\((.+)\)$/)
      return -BigDecimal($1)
    end

    BigDecimal(cleaned) rescue nil
  end
end
