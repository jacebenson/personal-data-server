class DataUploadsController < ApplicationController
  before_action :authenticate_user!

  def index
    # Show all available upload types
  end

  def ally_bank_statements
    # Show Ally bank statement upload form
  end

  def upload_ally_bank_statements
    # Process uploaded Ally bank statement CSV
    if params[:file].present?
      begin
        column_mapping = {
          date_column: params[:date_column],
          time_column: params[:time_column],
          description_column: params[:description_column],
          amount_column: params[:amount_column],
          category_column: params[:category_column],
          default_account: params[:default_account]
        }

        result = BankStatementProcessor.new(params[:file], current_user, column_mapping).process

        message = "Successfully imported #{result[:count]} Ally bank statement records."
        if result[:skipped] && result[:skipped] > 0
          message += " Skipped #{result[:skipped]} records"
          if result[:duplicates] && result[:duplicates] > 0
            message += " (#{result[:duplicates]} duplicates)"
          end
          message += "."
        end

        redirect_to data_uploads_path, notice: message
      rescue => e
        redirect_to ally_bank_statements_data_uploads_path, alert: "Error processing file: #{e.message}"
      end
    else
      redirect_to ally_bank_statements_data_uploads_path, alert: "Please select a file to upload."
    end
  end

  def view_ally_bank_statements
    # Show imported Ally bank statement records
    page = params[:page].to_i
    page = 1 if page < 1
    per_page = 50
    offset = (page - 1) * per_page

    # Filter by account if specified
    statements_scope = current_user.bank_statements
    statements_scope = statements_scope.where(account: params[:account]) if params[:account].present?

    @bank_statements = statements_scope.order(date: :desc).limit(per_page).offset(offset)
    @total_count = statements_scope.count
    @current_page = page
    @total_pages = (@total_count.to_f / per_page).ceil
    @has_next = page < @total_pages
    @has_prev = page > 1
    @filtered_account = params[:account]

    # Overall totals (always show all accounts in summary)
    @total_deposits = current_user.bank_statements.where("amount > 0").sum(:amount)
    @total_withdrawals = current_user.bank_statements.where("amount < 0").sum(:amount)
    @date_range = {
      earliest: current_user.bank_statements.minimum(:date),
      latest: current_user.bank_statements.maximum(:date)
    }

    # Account-based groupings (always show all accounts)
    @account_summaries = current_user.bank_statements
      .group(:account)
      .group("CASE WHEN amount > 0 THEN 'deposits' ELSE 'withdrawals' END")
      .sum(:amount)
      .each_with_object({}) do |((account, type), total), hash|
        hash[account] ||= { deposits: 0, withdrawals: 0, count: 0 }
        if type == "deposits"
          hash[account][:deposits] = total
        else
          hash[account][:withdrawals] = total.abs
        end
      end

    # Add transaction counts per account
    account_counts = current_user.bank_statements.group(:account).count
    @account_summaries.each do |account, data|
      data[:count] = account_counts[account] || 0
      data[:net] = data[:deposits] - data[:withdrawals]
    end

    # Sort accounts by total activity (deposits + withdrawals)
    @account_summaries = @account_summaries.sort_by do |account, data|
      -(data[:deposits] + data[:withdrawals])
    end.to_h
  end

  def manage_duplicates
    # Find duplicates based on date, amount, description (ignoring account name)
    # First get the duplicate groups, then fetch details for each
    duplicate_groups = current_user.bank_statements
                                  .group(:date, :amount, :description)
                                  .having("COUNT(*) > 1")
                                  .count

    @duplicates = []
    duplicate_groups.each do |(date, amount, description), count|
      records = current_user.bank_statements.where(
        date: date,
        amount: amount,
        description: description
      )

      @duplicates << {
        date: date,
        amount: amount,
        description: description,
        count: count,
        ids: records.pluck(:id).join(","),
        accounts: records.pluck(:account).uniq.join(",")
      }
    end
  end

  def remove_duplicates
    # Remove duplicates, keeping the first occurrence (ignoring account name)
    current_user.bank_statements.where(
      "id NOT IN (SELECT MIN(id) FROM bank_statements GROUP BY user_id, date, amount, description)"
    ).delete_all

    redirect_to manage_duplicates_data_uploads_path, notice: "Removed duplicate transactions."
  end

  def remove_account_transactions
    account_name = params[:account]

    if account_name.blank?
      redirect_to view_ally_bank_statements_data_uploads_path, alert: "No account specified."
      return
    end

    deleted_count = current_user.bank_statements.where(account: account_name).delete_all

    redirect_to view_ally_bank_statements_data_uploads_path,
                notice: "Removed #{deleted_count} transactions from #{account_name} account."
  end

  def remove_all_transactions
    deleted_count = current_user.bank_statements.delete_all

    redirect_to data_uploads_path,
                notice: "Removed all #{deleted_count} bank statement transactions."
  end

  # Investment upload methods
  def fidelity_data
    # Combined Fidelity upload page for both transactions and positions
  end

  def upload_fidelity_data
    # Process uploaded Fidelity CSV (either transactions or positions)
    if params[:file].present?
      begin
        # Detect file type based on content or filename
        file_type = detect_fidelity_file_type(params[:file])

        if file_type == "transactions"
          result = FidelityInvestmentProcessor.new(params[:file], current_user).process
          message = "Successfully imported #{result[:count]} Fidelity investment transactions."
        else # positions
          result = FidelityPortfolioProcessor.process(params[:file].path, current_user)
          message = "Successfully imported #{result[:imported]} Fidelity portfolio positions."
          if result[:replaced_accounts] && result[:replaced_accounts].any?
            message += " Replaced positions for: #{result[:replaced_accounts].join(', ')}."
          end
        end

        if result[:skipped] && result[:skipped] > 0
          message += " Skipped #{result[:skipped]} records"
          if result[:duplicates] && result[:duplicates] > 0
            message += " (#{result[:duplicates]} duplicates)"
          end
          message += "."
        end

        redirect_to fidelity_data_data_uploads_path, notice: message
      rescue => e
        redirect_to fidelity_data_data_uploads_path, alert: "Error processing file: #{e.message}"
      end
    else
      redirect_to fidelity_data_data_uploads_path, alert: "Please select a file to upload."
    end
  end

  def principal_investments
    # Show Principal investment upload form
  end

  def upload_principal_investments
    # Process uploaded Principal investment OFX
    if params[:file].present?
      begin
        result = PrincipalOfxProcessor.new(params[:file], current_user).process

        message = "Successfully imported #{result[:count]} Principal investment records."
        if result[:skipped] && result[:skipped] > 0
          message += " Skipped #{result[:skipped]} records"
          if result[:duplicates] && result[:duplicates] > 0
            message += " (#{result[:duplicates]} duplicates)"
          end
          message += "."
        end

        redirect_to data_uploads_path, notice: message
      rescue => e
        redirect_to principal_investments_data_uploads_path, alert: "Error processing file: #{e.message}"
      end
    else
      redirect_to principal_investments_data_uploads_path, alert: "Please select a file to upload."
    end
  end

  def view_investments
    # Show imported investment records
    page = params[:page].to_i
    page = 1 if page < 1
    per_page = 50
    offset = (page - 1) * per_page

    # Filter by account if specified
    investments_scope = current_user.investments
    investments_scope = investments_scope.where(account: params[:account]) if params[:account].present?

    @investments = investments_scope.order(date: :desc).limit(per_page).offset(offset)
    @total_count = investments_scope.count
    @current_page = page
    @total_pages = (@total_count.to_f / per_page).ceil
    @has_next = page < @total_pages
    @has_prev = page > 1
    @filtered_account = params[:account]

    # Overall totals (always show all accounts in summary)
    @total_purchases = current_user.investments.where("amount < 0").sum(:amount).abs
    @total_sales = current_user.investments.where("amount > 0").sum(:amount)
    @date_range = {
      earliest: current_user.investments.minimum(:date),
      latest: current_user.investments.maximum(:date)
    }

    # Account-based groupings (always show all accounts)
    @account_summaries = current_user.investments
      .group(:account)
      .group("CASE WHEN amount > 0 THEN 'sales' ELSE 'purchases' END")
      .sum(:amount)
      .each_with_object({}) do |((account, type), total), hash|
        hash[account] ||= { purchases: 0, sales: 0, count: 0 }
        if type == "sales"
          hash[account][:sales] = total
        else
          hash[account][:purchases] = total.abs
        end
      end

    # Add investment counts per account
    account_counts = current_user.investments.group(:account).count
    @account_summaries.each do |account, data|
      data[:count] = account_counts[account] || 0
      data[:net] = data[:sales] - data[:purchases]
    end

    # Sort accounts by total activity (purchases + sales)
    @account_summaries = @account_summaries.sort_by do |account, data|
      -(data[:purchases] + data[:sales])
    end.to_h
  end

  def clear_investments
    # Clear all investment records for the current user
    count = current_user.investments.count
    current_user.investments.destroy_all
    redirect_to data_uploads_path, notice: "Successfully deleted #{count} investment records."
  end

  # Social Security earnings methods
  def social_security_earnings
    # Show Social Security earnings upload form
  end

  def upload_social_security_earnings
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

        redirect_to data_uploads_path, notice: message
      rescue => e
        # Clean up temp file on error
        File.delete(temp_file) if defined?(temp_file) && File.exist?(temp_file)
        redirect_to social_security_earnings_data_uploads_path, alert: "Error processing file: #{e.message}"
      end
    else
      redirect_to social_security_earnings_data_uploads_path, alert: "Please select a file to upload."
    end
  end

  def view_social_security_earnings
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

  # Amazon shopping methods
  def amazon_orders
    # Combined Amazon upload page for both digital and retail orders
  end

  def upload_amazon_orders
    # Process uploaded Amazon CSV (either digital or retail)
    if params[:file].present?
      begin
        # Detect file type based on content or filename
        file_type = detect_amazon_file_type(params[:file])

        result = AmazonDataProcessor.new(params[:file].path, current_user, file_type).process

        message = "Successfully imported #{result[:count]} Amazon #{file_type} orders."
        if result[:skipped] && result[:skipped] > 0
          message += " Skipped #{result[:skipped]} records"
          if result[:duplicates] && result[:duplicates] > 0
            message += " (#{result[:duplicates]} duplicates)"
          end
          message += "."
        end

        redirect_to amazon_orders_data_uploads_path, notice: message
      rescue => e
        redirect_to amazon_orders_data_uploads_path, alert: "Error processing file: #{e.message}"
      end
    else
      redirect_to amazon_orders_data_uploads_path, alert: "Please select a file to upload."
    end
  end

  def view_amazon_orders
    # Show imported Amazon orders
    page = params[:page].to_i
    page = 1 if page < 1
    per_page = 50
    offset = (page - 1) * per_page

    @filter_type = params[:filter_type] || "all"
    @filter_year = params[:filter_year]

    # Base query
    orders = current_user.amazon_orders

    # Apply filters
    case @filter_type
    when "digital"
      orders = orders.digital
    when "retail"
      orders = orders.retail
    end

    if @filter_year.present?
      orders = orders.by_year(@filter_year)
    end

    @total_count = orders.count
    @orders = orders.recent.limit(per_page).offset(offset)

    # Pagination info
    @current_page = page
    @total_pages = (@total_count.to_f / per_page).ceil
    @has_prev = page > 1
    @has_next = page < @total_pages

    # Summary stats
    @digital_count = current_user.amazon_orders.digital.count
    @retail_count = current_user.amazon_orders.retail.count
    @subscription_count = current_user.amazon_orders.unique_subscriptions_count
    @one_time_count = current_user.amazon_orders.one_time_purchases.count
    @total_spent_digital = current_user.amazon_orders.digital.sum(:our_price) || 0
    @total_spent_retail = current_user.amazon_orders.retail.sum(:total_owed) || 0
    @years_available = current_user.amazon_orders.pluck(:order_date).map { |d| d.year }.uniq.sort.reverse
  end

  def clear_amazon_orders
    # Clear all Amazon orders for the current user
    count = current_user.amazon_orders.count
    current_user.amazon_orders.destroy_all
    redirect_to data_uploads_path, notice: "Successfully deleted #{count} Amazon orders."
  end



  private

  def detect_amazon_file_type(file)
    # Check filename first
    filename = file.original_filename.downcase
    return "digital" if filename.include?("digital")
    return "retail" if filename.include?("retail")

    # If filename doesn't give us a clue, read first few lines to detect headers
    begin
      first_line = File.open(file.path, "r") { |f| f.readline }.strip
      headers = first_line.split(",").map(&:strip).map(&:downcase)

      # Digital files typically have these headers
      digital_indicators = [ "title", "asin", "website", "order date" ]
      # Retail files typically have these headers
      retail_indicators = [ "order date", "order id", "product name", "category" ]

      digital_score = digital_indicators.count { |indicator| headers.any? { |h| h.include?(indicator) } }
      retail_score = retail_indicators.count { |indicator| headers.any? { |h| h.include?(indicator) } }

      digital_score > retail_score ? "digital" : "retail"
    rescue
      # Default to digital if we can't detect
      "digital"
    end
  end

  def detect_fidelity_file_type(file)
    # Check filename first
    filename = file.original_filename.downcase
    return "positions" if filename.include?("position") || filename.include?("portfolio")
    return "transactions" if filename.include?("transaction") || filename.include?("history")

    # If filename doesn't give us a clue, read first few lines to detect headers
    begin
      first_line = File.open(file.path, "r") { |f| f.readline }.strip
      headers = first_line.split(",").map(&:strip).map(&:downcase)

      # Portfolio/Positions files typically have these headers
      position_indicators = [ "current value", "quantity", "last price", "market value" ]
      # Transaction files typically have these headers
      transaction_indicators = [ "run date", "transaction type", "action", "settlement date" ]

      position_score = position_indicators.count { |indicator| headers.any? { |h| h.include?(indicator) } }
      transaction_score = transaction_indicators.count { |indicator| headers.any? { |h| h.include?(indicator) } }

      position_score > transaction_score ? "positions" : "transactions"
    rescue
      # Default to transactions if we can't detect
      "transactions"
    end
  end
end
