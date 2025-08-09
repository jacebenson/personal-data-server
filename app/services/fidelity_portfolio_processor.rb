require "csv"

class FidelityPortfolioProcessor
  def self.process(file_path, user)
    results = { imported: 0, skipped: 0, errors: [], replaced_accounts: [] }

    # Keep track of accounts we're replacing positions for
    accounts_to_replace = Set.new

    begin
      # First pass: identify all accounts in the file
      CSV.foreach(file_path, headers: true, encoding: "UTF-8") do |row|
        next if row.to_h.values.all?(&:blank?) # Skip empty rows
        
        account_number = row["Account Number"] || row["﻿Account Number"]
        account_name = row["Account Name"]
        
        # Skip if no valid account number or account name
        next if account_number.blank? || account_name.blank?
        
        # Skip disclaimer/footer rows that start with quotes or contain long text
        next if account_number.to_s.start_with?('"') || account_name.to_s.start_with?('"')
        next if account_number.to_s.length > 50 || account_name.to_s.length > 100
        
        # Skip rows that look like disclaimers (contain common disclaimer keywords)
        disclaimer_keywords = ['fidelity', 'brokerage', 'services', 'provided', 'llc', 'data', 'information', 'spreadsheet', 'downloaded', 'sipc', 'nyse']
        next if disclaimer_keywords.any? { |keyword| account_number.to_s.downcase.include?(keyword) || account_name.to_s.downcase.include?(keyword) }
        
        full_account_name = "#{account_number} - #{account_name}"
        accounts_to_replace.add(full_account_name)
      end

      # Delete existing positions for these accounts
      accounts_to_replace.each do |account_name|
        deleted_count = user.investments.where(account: account_name, action: ['POSITION', 'CASH_POSITION']).delete_all
        results[:replaced_accounts] << "#{account_name} (#{deleted_count} old positions removed)"
      end

      # Second pass: import new positions
      CSV.foreach(file_path, headers: true, encoding: "UTF-8") do |row|
        next if row.to_h.values.all?(&:blank?) # Skip empty rows

        account_number = row["Account Number"] || row["﻿Account Number"]  # Handle BOM character
        account_name = row["Account Name"]
        
        # Skip if no valid account number or account name
        next if account_number.blank? || account_name.blank?
        
        # Skip disclaimer/footer rows that start with quotes or contain long text
        next if account_number.to_s.start_with?('"') || account_name.to_s.start_with?('"')
        next if account_number.to_s.length > 50 || account_name.to_s.length > 100
        
        # Skip rows that look like disclaimers (contain common disclaimer keywords)
        disclaimer_keywords = ['fidelity', 'brokerage', 'services', 'provided', 'llc', 'data', 'information', 'spreadsheet', 'downloaded', 'sipc', 'nyse']
        next if disclaimer_keywords.any? { |keyword| account_number.to_s.downcase.include?(keyword) || account_name.to_s.downcase.include?(keyword) }

        # Convert position to a transaction-like record for consistency
        investment_params = {
          user: user,
          date: Date.current, # Use current date since this is a position snapshot
          account: "#{account_number} - #{account_name}",
          action: "POSITION", # Special action type for positions
          symbol: row["Symbol"],
          description: row["Description"],
          quantity: parse_number(row["Quantity"]),
          price: parse_currency(row["Last Price"]),
          amount: parse_currency(row["Current Value"])
        }

        # Skip cash positions with no quantity/price
        if investment_params[:symbol]&.include?("CASH") || investment_params[:symbol]&.include?("**")
          if investment_params[:amount] && investment_params[:amount] > 0
            # Create a cash position record
            investment_params[:action] = "CASH_POSITION"
            investment_params[:quantity] = nil
            investment_params[:price] = nil
          else
            next # Skip zero cash positions
          end
        end

        # Skip if no value
        next if investment_params[:amount].blank? || investment_params[:amount] == 0

        investment = Investment.new(investment_params)

        if investment.save
          results[:imported] += 1
        else
          results[:skipped] += 1
          Rails.logger.info "Skipped investment: #{investment.errors.full_messages.join(', ')}"
        end
      end

    rescue => e
      results[:errors] << "Error processing file: #{e.message}"
      Rails.logger.error "FidelityPortfolioProcessor error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end

    results
  end

  private

  def self.parse_number(value)
    return nil if value.blank?
    # Remove any non-numeric characters except decimal point and negative sign
    cleaned = value.to_s.gsub(/[^\d.-]/, "")
    cleaned.blank? ? nil : cleaned.to_f
  end

  def self.parse_currency(value)
    return nil if value.blank?
    # Remove currency symbols and commas, handle parentheses for negative values
    cleaned = value.to_s.gsub(/[$,]/, "")

    # Handle parentheses for negative values
    if cleaned.include?("(") && cleaned.include?(")")
      cleaned = "-" + cleaned.gsub(/[()+-]/, "")
    else
      cleaned = cleaned.gsub(/[^0-9.-]/, "")
    end

    cleaned.blank? ? nil : cleaned.to_f
  end
end
