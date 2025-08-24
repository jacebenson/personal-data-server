require "nokogiri"

class PrincipalOfxProcessor
  def initialize(file, user)
    @file = file
    @user = user
    @imported_count = 0
    @skipped_count = 0
    @duplicate_count = 0
  end

  def process
    Rails.logger.info "\n=== DEBUG: Starting Principal OFX Processing ==="

    content = File.read(@file.path)

    # OFX files often have a header followed by XML content
    # Find the start of XML content (usually starts with <OFX>)
    xml_start = content.index("<OFX>")
    if xml_start
      xml_content = content[xml_start..-1]
      Rails.logger.info "DEBUG: Found OFX XML content starting at position #{xml_start}"
    else
      xml_content = content
      Rails.logger.info "DEBUG: No <OFX> tag found, treating entire file as XML"
    end

    Rails.logger.info "DEBUG: Original XML length: #{xml_content.length} characters"

    # Use regular XML parsing since the file structure is actually valid XML
    doc = Nokogiri::XML(xml_content)
    Rails.logger.info "DEBUG: Parsed as XML"
    Rails.logger.info "DEBUG: Document root element: #{doc.root&.name}"
    Rails.logger.info "DEBUG: First 500 chars of XML content: #{xml_content[0, 500]}"

    # Extract security names first
    @security_names = extract_security_names(doc)
    Rails.logger.info "DEBUG: Found #{@security_names.count} securities: #{@security_names.inspect}"

    account_info = extract_account_info(doc)
    Rails.logger.info "DEBUG: Account info: #{account_info.inspect}"

    # Find all transaction elements directly
    transaction_nodes = doc.xpath("//BUYMF | //SELLMF | //REINVEST | //INCOME")
    Rails.logger.info "DEBUG: Found #{transaction_nodes.count} transaction nodes"

    import_count = 0

    transaction_nodes.each_with_index do |transaction_node, index|
      Rails.logger.info "\nDEBUG: Processing transaction #{index + 1}: #{transaction_node.name}"

      begin
        # Extract transaction data using the proper XML structure
        action, symbol, description, quantity, price, amount, trade_date = extract_transaction_details_from_xml(transaction_node)

        next if trade_date.nil? || amount.nil?

        Rails.logger.info "DEBUG: Extracted - Date: #{trade_date}, Action: #{action}, Symbol: #{symbol}, Description: #{description}, Quantity: #{quantity}, Price: #{price}, Amount: #{amount}"

        # Create investment record
        investment = Investment.new(
          user: @user,
          account: account_info[:display_name],
          date: trade_date,
          action: action,
          symbol: symbol,
          description: description,
          quantity: quantity,
          price: price,
          amount: amount
        )

        if investment.save
          import_count += 1
          Rails.logger.info "DEBUG: Successfully saved investment #{import_count}"
        else
          Rails.logger.info "DEBUG: Failed to save investment: #{investment.errors.full_messages}"
        end

      rescue => e
        Rails.logger.info "DEBUG: Error processing transaction #{index + 1}: #{e.message}"
        Rails.logger.info "DEBUG: Backtrace: #{e.backtrace.first(3)}"
      end
    end

    Rails.logger.info "\nDEBUG: Final import count: #{import_count}"

    { count: import_count, account: account_info[:display_name] }
  end

  private

  def extract_transaction_details_from_xml(transaction_node)
    # Extract transaction date first
    invtran = transaction_node.at_xpath(".//INVTRAN")
    return [ nil, nil, nil, nil, nil, nil, nil ] unless invtran

    date_text = invtran.at_xpath("DTTRADE")&.text&.strip
    return [ nil, nil, nil, nil, nil, nil, nil ] if date_text.blank?

    trade_date = parse_ofx_date(date_text)
    return [ nil, nil, nil, nil, nil, nil, nil ] if trade_date.nil?

    # Determine action from node name
    action = case transaction_node.name
    when "BUYMF" then "BUY"
    when "SELLMF" then "SELL"
    when "REINVEST" then "REINVEST"
    when "INCOME" then "DIVIDEND"
    else "OTHER"
    end

    # Find the INVBUY or INVSELL container
    inv_container = transaction_node.at_xpath("INVBUY") || transaction_node.at_xpath("INVSELL")
    return [ nil, nil, nil, nil, nil, nil, nil ] unless inv_container

    # Extract symbol from SECID
    secid = inv_container.at_xpath("SECID")
    symbol = secid&.at_xpath("UNIQUEID")&.text&.strip&.split&.first

    # Extract financial data - the issue here is that the XML is malformed
    # with data concatenated in the UNIQUEID field, let's extract it properly

    if secid
      # The UNIQUEID field contains concatenated data including the actual values
      uniqueid_text = secid.at_xpath("UNIQUEID")&.text

      if uniqueid_text
        # Parse the concatenated string to extract financial values
        # Format appears to be: SYMBOL IDTYPE UNITS PRICE TOTAL OTHERS...
        parts = uniqueid_text.strip.split(/\s+/)

        if parts.length >= 5
          # parts[0] = symbol (220492220)
          # parts[1] = type (CUSIP)
          # parts[2] = units/quantity
          # parts[3] = unit price
          # parts[4] = total amount

          symbol = parts[0]
          quantity = parse_decimal(parts[2])
          price = parse_decimal(parts[3])
          amount = parse_decimal(parts[4])

          # Make amount positive for buys (OFX typically has negative amounts for purchases)
          if action == "BUY" && amount&.negative?
            amount = amount.abs
          end

          # Make quantity positive for sells
          if action == "SELL" && quantity&.negative?
            quantity = quantity.abs
          end
        end
      end
    end

    # Get security description
    description = get_security_name(symbol)

    [ action, symbol, description, quantity, price, amount, trade_date ]
  end

  def extract_transaction_details(transaction_node)
    # This method is no longer used - keeping for compatibility
    # Use extract_transaction_details_from_xml instead
    []
  end

  def get_security_name(symbol)
    return symbol if symbol.blank?
    # Use the security names we extracted from SECLIST
    @security_names[symbol] || symbol
  end

  def extract_security_names(doc)
    security_names = {}

    # Extract security names from SECLIST section
    doc.xpath("//SECLIST//SECINFO").each do |secinfo|
      unique_id = secinfo.at_xpath("SECID/UNIQUEID")&.text&.split&.first&.strip
      name = secinfo.at_xpath("SECNAME")&.text&.strip

      if unique_id.present? && name.present?
        security_names[unique_id] = name
      end
    end

    security_names
  end

  def extract_account_info(doc)
    # Extract account information from OFX header
    account_id = doc.at_xpath("//ACCTID")&.text&.strip
    account_type = doc.at_xpath("//ACCTTYPE")&.text&.strip
    broker_id = doc.at_xpath("//BROKERID")&.text&.split&.first&.strip # Take first word only

    # Create a display name combining available information
    account_parts = []
    account_parts << account_id if account_id.present?
    account_parts << "Principal 401(K)" # Default for Principal
    account_parts << account_type if account_type.present? && account_type != account_id

    display_name = account_parts.join(" - ")

    {
      account_id: account_id,
      account_type: account_type,
      broker_id: broker_id,
      display_name: display_name
    }
  end

  def parse_ofx_date(date_string)
    return nil if date_string.blank?

    # OFX dates are typically in YYYYMMDDHHMMSS format
    # Extract just the date part (first 8 characters)
    date_part = date_string[0, 8]

    begin
      Date.strptime(date_part, "%Y%m%d").beginning_of_day
    rescue ArgumentError
      Rails.logger.warn "Could not parse OFX date: #{date_string}"
      nil
    end
  end

  def parse_decimal(value_string)
    return nil if value_string.blank?

    begin
      value_string.to_f
    rescue
      nil
    end
  end
end
