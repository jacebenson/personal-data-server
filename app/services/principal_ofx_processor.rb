class PrincipalOfxProcessor
  def initialize(file, user)
    @file = file
    @user = user
    @imp    # Parse values
    quantity = parse_decimal(units)
    price = parse_decimal(unit_price)
    amount = parse_decimal(total)

    # Create account name for Principal
    account_name = "Principal #{account_id}"

    # Check if this investment transaction already exists (including account name)
    existing_investment = @user.investments.find_by(
      date: trade_date,
      amount: amount,
      description: description,
      account: account_name
    ) = 0
    @skipped_count = 0
    @duplicate_count = 0
  end

  def process
    Rails.logger.info "Starting Principal OFX processing"

    # Read the OFX file
    content = File.read(@file.path)

    # Parse the OFX content
    parse_ofx_content(content)

    Rails.logger.info "Finished processing. Imported #{@imported_count} records, skipped #{@skipped_count} duplicates."
    {
      count: @imported_count,
      skipped: @skipped_count,
      duplicates: @duplicate_count
    }
  end

  private

  def parse_ofx_content(content)
    # Remove OFX headers and keep only the XML part
    xml_start = content.index('<OFX>')
    return unless xml_start

    xml_content = content[xml_start..-1]

    # Parse XML with Nokogiri
    doc = Nokogiri::XML(xml_content)

    # Extract account information
    account_id = doc.at_xpath('//ACCTID')&.text
    broker_id = doc.at_xpath('//BROKERID')&.text

    # Process different transaction types
    process_buy_transactions(doc, account_id, broker_id)
    process_sell_transactions(doc, account_id, broker_id)
    process_dividend_transactions(doc, account_id, broker_id)
    process_other_transactions(doc, account_id, broker_id)
  end

  def process_buy_transactions(doc, account_id, broker_id)
    doc.xpath('//BUYMF | //BUYSTOCK | //BUYOTHER').each do |buy_node|
      process_investment_transaction(buy_node, 'BUY', account_id, broker_id)
    end
  end

  def process_sell_transactions(doc, account_id, broker_id)
    doc.xpath('//SELLMF | //SELLSTOCK | //SELLOTHER').each do |sell_node|
      process_investment_transaction(sell_node, 'SELL', account_id, broker_id)
    end
  end

  def process_dividend_transactions(doc, account_id, broker_id)
    doc.xpath('//INCOME').each do |income_node|
      process_investment_transaction(income_node, 'DIVIDEND', account_id, broker_id)
    end
  end

  def process_other_transactions(doc, account_id, broker_id)
    doc.xpath('//REINVEST | //TRANSFER').each do |other_node|
      action = other_node.name == 'REINVEST' ? 'REINVESTMENT' : 'TRANSFER'
      process_investment_transaction(other_node, action, account_id, broker_id)
    end
  end

  def process_investment_transaction(node, action_type, account_id, broker_id)
    # Extract common investment transaction data
    invtran = node.at_xpath('.//INVTRAN')
    invbuy = node.at_xpath('.//INVBUY')

    return unless invtran

    # Extract transaction details
    fitid = invtran.at_xpath('.//FITID')&.text
    trade_date = parse_ofx_date(invtran.at_xpath('.//DTTRADE')&.text)

    # Extract security information
    secid = node.at_xpath('.//SECID')
    symbol = secid&.at_xpath('.//UNIQUEID')&.text

    # Extract financial details
    units = invbuy&.at_xpath('.//UNITS')&.text || node.at_xpath('.//UNITS')&.text
    unit_price = invbuy&.at_xpath('.//UNITPRICE')&.text || node.at_xpath('.//UNITPRICE')&.text
    total = invbuy&.at_xpath('.//TOTAL')&.text || node.at_xpath('.//TOTAL')&.text

    # Create description from available information
    description = "#{action_type}"
    description += " #{symbol}" if symbol
    description += " (#{fitid})" if fitid

    # Parse values
    quantity = parse_decimal(units)
    price = parse_decimal(unit_price)
    amount = parse_decimal(total)

    # Check if this investment transaction already exists (ignoring account name)
    existing_investment = @user.investments.find_by(
      date: trade_date,
      amount: amount,
      description: description
    )

    if existing_investment
      @duplicate_count += 1
      @skipped_count += 1
      Rails.logger.info "Skipping duplicate investment: #{description} on #{trade_date} for #{amount}"
      return
    end

    # Debug logging
    Rails.logger.info "Processing OFX investment: #{description} on #{trade_date} for #{amount}"

    investment = @user.investments.build(
      date: trade_date,
      action: action_type,
      symbol: symbol,
      description: description,
      investment_type: 'MUTUAL_FUND', # Default for Principal
      quantity: quantity,
      price: price,
      amount: amount,
      account: "Principal #{account_id}",
      account_number: account_id
    )

    if investment.save
      @imported_count += 1
      Rails.logger.info "Successfully saved investment #{@imported_count}"
    else
      @skipped_count += 1
      Rails.logger.error "Failed to save investment: #{investment.errors.full_messages}"
      Rails.logger.error "Investment attributes: #{investment.attributes}"
    end
  end

  def parse_ofx_date(date_string)
    return nil if date_string.blank?

    # OFX dates are typically in YYYYMMDD format
    if date_string.match(/^\d{8}$/)
      begin
        return Date.strptime(date_string, '%Y%m%d').beginning_of_day
      rescue ArgumentError
        # Fall through to other formats
      end
    end

    # Try other common formats
    ["%Y-%m-%d", "%m/%d/%Y", "%d/%m/%Y"].each do |format|
      begin
        return Date.strptime(date_string, format).beginning_of_day
      rescue ArgumentError
        next
      end
    end

    # If all formats fail, try Date.parse
    begin
      Date.parse(date_string).beginning_of_day
    rescue ArgumentError
      nil
    end
  end

  def parse_decimal(amount_string)
    return 0 if amount_string.blank?

    # Remove currency symbols and commas
    cleaned = amount_string.to_s.gsub(/[\$,£€]/, '').strip
    BigDecimal(cleaned) rescue 0
  end
end
