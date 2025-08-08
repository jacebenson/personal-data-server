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
  def fidelity_investments
    # Show Fidelity investment upload form
  end

  def upload_fidelity_investments
    puts "DEBUGGING: upload_fidelity_investments called"
    Rails.logger.info "DEBUGGING: upload_fidelity_investments called with params: #{params.inspect}"

    # Process uploaded Fidelity investment CSV
    if params[:file].present?
      puts "DEBUGGING: File present: #{params[:file].original_filename}"
      Rails.logger.info "DEBUGGING: File present: #{params[:file].original_filename}"

      begin
        result = FidelityInvestmentProcessor.new(params[:file], current_user).process

        message = "Successfully imported #{result[:count]} Fidelity investment records."
        if result[:skipped] && result[:skipped] > 0
          message += " Skipped #{result[:skipped]} records"
          if result[:duplicates] && result[:duplicates] > 0
            message += " (#{result[:duplicates]} duplicates)"
          end
          message += "."
        end

        redirect_to data_uploads_path, notice: message
      rescue => e
        puts "DEBUGGING: Error processing file: #{e.message}"
        Rails.logger.error "DEBUGGING: Error processing file: #{e.message}"
        Rails.logger.error "DEBUGGING: Backtrace: #{e.backtrace.join("\n")}"
        redirect_to fidelity_investments_data_uploads_path, alert: "Error processing file: #{e.message}"
      end
    else
      redirect_to fidelity_investments_data_uploads_path, alert: "Please select a file to upload."
    end
  end

  def fidelity_portfolio
    # Show Fidelity portfolio upload form
  end

  def upload_fidelity_portfolio
    # Process uploaded Fidelity portfolio positions CSV
    if params[:file].present?
      begin
        result = FidelityPortfolioProcessor.process(params[:file].path, current_user)

        message = "Successfully imported #{result[:imported]} Fidelity portfolio positions."
        if result[:skipped] && result[:skipped] > 0
          message += " Skipped #{result[:skipped]} records."
        end

        redirect_to data_uploads_path, notice: message
      rescue => e
        Rails.logger.error "Error processing Fidelity portfolio: #{e.message}"
        redirect_to fidelity_portfolio_data_uploads_path, alert: "Error processing file: #{e.message}"
      end
    else
      redirect_to fidelity_portfolio_data_uploads_path, alert: "Please select a file to upload."
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
end
