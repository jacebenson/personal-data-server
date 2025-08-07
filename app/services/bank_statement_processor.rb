class BankStatementProcessor
  def initialize(file, user, column_mapping = {})
    @file = file
    @user = user
    @column_mapping = column_mapping
    @imported_count = 0
    @skipped_count = 0
    @duplicate_count = 0
  end

  def process
    Rails.logger.info "Starting CSV processing with column mapping: #{@column_mapping}"

    CSV.foreach(@file.path, headers: true) do |row|
      create_bank_statement(row)
    end

    Rails.logger.info "Finished processing. Imported #{@imported_count} records, skipped #{@skipped_count} duplicates."
    {
      count: @imported_count,
      skipped: @skipped_count,
      duplicates: @duplicate_count
    }
  end

  private

  def create_bank_statement(row)
    # Use column mapping to get the correct values
    date_value = get_mapped_value(row, :date_column) || row["Date"] || row["date"]
    time_value = get_mapped_value(row, :time_column) || row["Time"] || row["time"]
    description_value = get_mapped_value(row, :description_column) || row["Description"] || row["description"]
    amount_value = get_mapped_value(row, :amount_column) || row["Amount"] || row["amount"]
    account_value = @column_mapping[:default_account] || "Unknown"
    category_value = get_mapped_value(row, :category_column) || row["Category"] || row["category"] || row["Type"] || row["type"]

    # Parse values
    parsed_date = parse_date_time(date_value, time_value)
    parsed_amount = parse_amount(amount_value)

    # Check if this transaction already exists
    existing_transaction = @user.bank_statements.find_by(
      date: parsed_date,
      amount: parsed_amount,
      description: description_value,
      account: account_value
    )

    if existing_transaction
      @duplicate_count += 1
      @skipped_count += 1
      Rails.logger.info "Skipping duplicate transaction: #{description_value} on #{parsed_date} for #{parsed_amount}"
      return
    end

    # Debug logging
    Rails.logger.info "Processing row: #{row.to_h}"
    Rails.logger.info "Mapped values - Date: #{date_value}, Time: #{time_value}, Description: #{description_value}, Amount: #{amount_value}, Account: #{account_value}, Category: #{category_value}"

    bank_statement = @user.bank_statements.build(
      date: parsed_date,
      description: description_value,
      amount: parsed_amount,
      account: account_value,
      category: category_value
    )

    if bank_statement.save
      @imported_count += 1
      Rails.logger.info "Successfully saved bank statement #{@imported_count}"
    else
      @skipped_count += 1
      Rails.logger.error "Failed to save bank statement: #{bank_statement.errors.full_messages}"
      Rails.logger.error "Bank statement attributes: #{bank_statement.attributes}"
    end
  end

  def get_mapped_value(row, column_key)
    column_name = @column_mapping[column_key]
    return nil if column_name.blank?
    row[column_name]
  end

  def parse_date_time(date_string, time_string = nil)
    return nil if date_string.blank?

    # If we have both date and time, combine them
    if time_string.present?
      combined = "#{date_string} #{time_string}"
      return parse_datetime(combined)
    end

    # Otherwise try to parse as datetime first, then fall back to date
    parse_datetime(date_string) || parse_date(date_string)
  end

  def parse_datetime(datetime_string)
    return nil if datetime_string.blank?

    # Try different datetime formats
    [ "%Y-%m-%d %H:%M:%S", "%Y-%m-%d %H:%M:%S.%L", "%m/%d/%Y %H:%M:%S", "%d/%m/%Y %H:%M:%S" ].each do |format|
      begin
        return DateTime.strptime(datetime_string, format)
      rescue ArgumentError
        next
      end
    end

    # If all formats fail, try DateTime.parse
    begin
      DateTime.parse(datetime_string)
    rescue ArgumentError
      nil
    end
  end

  def parse_date(date_string)
    return nil if date_string.blank?

    # Try different date formats
    [ "%Y-%m-%d", "%m/%d/%Y", "%d/%m/%Y" ].each do |format|
      begin
        # Convert date to beginning of day datetime
        return Date.strptime(date_string, format).beginning_of_day
      rescue ArgumentError
        next
      end
    end

    # If all formats fail, try Date.parse and convert to beginning of day
    begin
      Date.parse(date_string).beginning_of_day
    rescue ArgumentError
      nil
    end
  end

  def parse_amount(amount_string)
    return 0 if amount_string.blank?

    # Remove currency symbols and commas
    cleaned = amount_string.to_s.gsub(/[\$,£€]/, "").strip
    BigDecimal(cleaned) rescue 0
  end
end
