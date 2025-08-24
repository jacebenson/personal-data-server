class BankStatementProcessor
  def initialize(file, user, column_mapping = {})
    @file = file
    @user = user
    @column_mapping = column_mapping
    @current_balance = column_mapping[:current_balance]
    @imported_count = 0
    @skipped_count = 0
    @duplicate_count = 0
  end

  def process
    Rails.logger.info "Starting CSV processing with column mapping: #{@column_mapping}"

    CSV.foreach(@file.path, headers: true) do |row|
      create_bank_statement(row)
    end

    # Create balance adjustment transaction if current_balance is provided
    create_balance_adjustment if @current_balance.present?

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

    # Check if this transaction already exists (ignoring account name)
    existing_transaction = @user.bank_statements.find_by(
      date: parsed_date,
      amount: parsed_amount,
      description: description_value
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

  def create_balance_adjustment
    account_name = @column_mapping[:default_account] || "Unknown"
    
    # Get the current balance from ALL transactions for this account
    all_account_transactions = @user.bank_statements.where(account: account_name)
    current_calculated_balance = all_account_transactions.sum(:amount)
    
    # Calculate the difference between expected and calculated balance
    target_balance = BigDecimal(@current_balance.to_s)
    balance_difference = target_balance - current_calculated_balance
    
    # Only create an adjustment if there's a meaningful difference (> $0.01)
    # AND we actually want to true up to the current balance
    if balance_difference.abs > 0.01
      # Check if this account already has balance adjustments
      existing_adjustments = all_account_transactions.where(category: "Balance Adjustment")
      
      if existing_adjustments.exists?
        Rails.logger.info "Skipping balance adjustment for #{account_name} - account already has balance adjustments. Current balance: #{current_calculated_balance}, Target: #{target_balance}"
        return
      end
      
      adjustment_description = if balance_difference > 0
        "Balance Adjustment - Missing Credits"
      else
        "Balance Adjustment - Missing Debits"
      end
      
      # Create the balance adjustment transaction
      adjustment = @user.bank_statements.build(
        date: Time.current,
        description: adjustment_description,
        amount: balance_difference,
        account: account_name,
        category: "Balance Adjustment"
      )
      
      if adjustment.save
        @imported_count += 1
        Rails.logger.info "Created balance adjustment of #{balance_difference} for account #{account_name}"
      else
        Rails.logger.error "Failed to create balance adjustment: #{adjustment.errors.full_messages}"
      end
    else
      Rails.logger.info "No balance adjustment needed. Calculated: #{current_calculated_balance}, Target: #{target_balance}"
    end
  end
end
