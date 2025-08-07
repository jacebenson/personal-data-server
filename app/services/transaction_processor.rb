class TransactionProcessor
  def initialize(file, user)
    @file = file
    @user = user
    @imported_count = 0
  end

  def process
    CSV.foreach(@file.path, headers: true) do |row|
      create_transaction(row)
    end

    { count: @imported_count }
  end

  private

  def create_transaction(row)
    transaction = @user.transactions.build(
      date: parse_date(row["Date"] || row["date"]),
      description: row["Description"] || row["description"],
      amount: parse_amount(row["Amount"] || row["amount"]),
      transaction_type: row["Type"] || row["type"] || "general",
      reference: row["Reference"] || row["reference"]
    )

    if transaction.save
      @imported_count += 1
    else
      Rails.logger.error "Failed to save transaction: #{transaction.errors.full_messages}"
    end
  end

  def parse_date(date_string)
    return nil if date_string.blank?

    [ "%Y-%m-%d", "%m/%d/%Y", "%d/%m/%Y" ].each do |format|
      begin
        return Date.strptime(date_string, format)
      rescue ArgumentError
        next
      end
    end

    Date.parse(date_string) rescue nil
  end

  def parse_amount(amount_string)
    return 0 if amount_string.blank?

    cleaned = amount_string.to_s.gsub(/[\$,£€]/, "").strip
    BigDecimal(cleaned) rescue 0
  end
end
