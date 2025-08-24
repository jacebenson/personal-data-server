class FinancialController < ApplicationController
  before_action :authenticate_user!

  def index
    @bank_statements_count = current_user.bank_statements.count
    @investments_count = current_user.investments.count
    @ssa_earnings_count = current_user.social_security_earnings.count

    @last_bank_upload = current_user.bank_statements.maximum(:created_at)
    @last_investment_upload = current_user.investments.maximum(:created_at)
    @last_ssa_upload = current_user.social_security_earnings.maximum(:created_at)
  end

  def bank_statements
    # Show bank statement upload form with existing accounts
    @existing_accounts = current_user.bank_statements.distinct.pluck(:account).compact.sort
  end

  def upload_bank_statements
    # Process uploaded Ally bank statement CSV
    if params[:file].present?
      begin
        column_mapping = {
          date_column: params[:date_column],
          time_column: params[:time_column],
          description_column: params[:description_column],
          amount_column: params[:amount_column],
          category_column: params[:category_column],
          default_account: params[:default_account],
          current_balance: params[:current_balance]
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

        redirect_to financial_path, notice: message
      rescue => e
        redirect_to financial_bank_statements_path, alert: "Error processing file: #{e.message}"
      end
    else
      redirect_to financial_bank_statements_path, alert: "Please select a file to upload."
    end
  end

  def add_balance_adjustment
    # Add a balance adjustment transaction
    account_name = params[:account_name]
    balance_amount = params[:balance_amount].to_f
    adjustment_date = Date.parse(params[:adjustment_date]) rescue Date.current

    current_user.bank_statements.create!(
      account: account_name,
      amount: balance_amount,
      date: adjustment_date,
      description: "Balance Adjustment - #{Date.current.strftime('%Y-%m-%d')}",
      transaction_type: "CREDIT"
    )

    redirect_to view_bank_statements_financial_index_path, notice: "Balance adjustment added successfully."
  end

  def view_bank_statements
    # View bank statements with pagination
    @page = params[:page]&.to_i || 1
    @per_page = 50
    offset = (@page - 1) * @per_page

    @bank_statements = current_user.bank_statements.order(date: :desc).limit(@per_page).offset(offset)
    @total_count = current_user.bank_statements.count
    @total_pages = (@total_count.to_f / @per_page).ceil

    # Calculate account summaries for the view
    @account_summaries = current_user.bank_statements.group_by(&:account).transform_values do |statements|
      deposits = statements.select { |s| s.amount > 0 }.sum(&:amount)
      withdrawals = statements.select { |s| s.amount < 0 }.sum(&:amount).abs
      total = statements.sum(&:amount)
      {
        count: statements.count,
        net: total,
        deposits: deposits,
        withdrawals: withdrawals,
        latest_date: statements.map(&:date).compact.max
      }
    end

    # Handle case where there are no statements
    @account_summaries ||= {}
  end

  def fidelity_upload
    # Fidelity upload form
  end

  def upload_fidelity_data
    # Handle fidelity data upload
    redirect_to view_investments_financial_index_path, notice: "Fidelity data uploaded successfully."
  end

  def principal_upload
    # Principal upload form
  end

  def upload_principal_data
    # Handle principal data upload
    redirect_to view_investments_financial_index_path, notice: "Principal data uploaded successfully."
  end

  def view_investments
    # View investments with pagination
    @page = params[:page]&.to_i || 1
    @per_page = 50
    offset = (@page - 1) * @per_page

    @investments = current_user.investments.order(date: :desc).limit(@per_page).offset(offset)
    @total_count = current_user.investments.count
    @total_pages = (@total_count.to_f / @per_page).ceil
  end

  def manage_duplicates
    # Manage duplicate transactions
    @duplicates = current_user.bank_statements.find_duplicates
  end

  def remove_duplicates
    # Remove duplicate transactions
    current_user.bank_statements.remove_duplicates
    redirect_to manage_duplicates_financial_index_path, notice: "Duplicates removed successfully."
  end

  def clear_bank_statements
    # Clear all bank statements
    current_user.bank_statements.destroy_all
    redirect_to financial_index_path, notice: "All bank statements cleared."
  end

  def clear_investments
    # Clear all investments
    current_user.investments.destroy_all
    redirect_to financial_index_path, notice: "All investments cleared."
  end

  def add_balance_adjustment
    # Add a balance adjustment transaction
    account_name = params[:account_name]
    balance_amount = params[:balance_amount].to_f
    adjustment_date = Date.parse(params[:adjustment_date]) rescue Date.current

    current_user.bank_statements.create!(
      account: account_name,
      amount: balance_amount,
      date: adjustment_date,
      description: "Balance Adjustment - #{Date.current.strftime('%Y-%m-%d')}",
      transaction_type: "CREDIT"
    )

    redirect_to view_bank_statements_financial_index_path, notice: "Balance adjustment added successfully."
  end

  def fidelity_upload
    # Combined Fidelity upload page for both transactions and positions
  end

  def upload_fidelity_data
    # Process uploaded Fidelity CSV for portfolio positions
    if params[:file].present?
      begin
        result = FidelityPortfolioProcessor.process(params[:file].path, current_user)
        message = "Successfully imported #{result[:imported]} Fidelity portfolio positions."
        if result[:replaced_accounts] && result[:replaced_accounts].any?
          message += " Replaced positions for: #{result[:replaced_accounts].join(', ')}."
        end

        if result[:skipped] && result[:skipped] > 0
          message += " Skipped #{result[:skipped]} records."
        end

        redirect_to financial_fidelity_upload_path, notice: message
      rescue => e
        redirect_to financial_fidelity_upload_path, alert: "Error processing file: #{e.message}"
      end
    else
      redirect_to financial_fidelity_upload_path, alert: "Please select a file to upload."
    end
  end

  def principal_upload
    # Show Principal investment upload form
  end

  def upload_principal_data
    # Process uploaded Principal QFX file
    if params[:file].present?
      begin
        result = PrincipalInvestmentProcessor.process(params[:file].path, current_user)

        message = "Successfully imported #{result[:imported]} Principal investment transactions."
        if result[:skipped] && result[:skipped] > 0
          message += " Skipped #{result[:skipped]} records"
          if result[:duplicates] && result[:duplicates] > 0
            message += " (#{result[:duplicates]} duplicates)"
          end
          message += "."
        end

        redirect_to financial_principal_upload_path, notice: message
      rescue => e
        redirect_to financial_principal_upload_path, alert: "Error processing file: #{e.message}"
      end
    else
      redirect_to financial_principal_upload_path, alert: "Please select a file to upload."
    end
  end

  def view_investments
    @page = params[:page]&.to_i || 1
    @per_page = 50
    offset = (@page - 1) * @per_page

    @investments = current_user.investments.includes(:user).order(date: :desc)

    # Apply filters
    if params[:search].present?
      @investments = @investments.where("description LIKE ? COLLATE NOCASE OR security LIKE ? COLLATE NOCASE",
                                       "%#{params[:search]}%", "%#{params[:search]}%")
    end

    if params[:account].present? && params[:account] != "all"
      @investments = @investments.where(account: params[:account])
    end

    if params[:action_filter].present? && params[:action_filter] != "all"
      @investments = @investments.where(action: params[:action_filter])
    end

    @total_count = @investments.count
    @total_pages = (@total_count / @per_page.to_f).ceil
    @investments = @investments.limit(@per_page).offset(offset)

    # For filters
    @available_accounts = current_user.investments.distinct.pluck(:account).compact.sort
    @available_actions = current_user.investments.distinct.pluck(:action).compact.sort
  end

  def manage_duplicates
    # Show duplicate management interface
    @total_transactions = current_user.bank_statements.count
    @duplicates = find_duplicate_groups
  end

  def remove_duplicates
    # Remove duplicate transactions
    deleted_count = 0

    if params[:selected_duplicates].present?
      params[:selected_duplicates].each do |duplicate_id|
        transaction = current_user.bank_statements.find(duplicate_id)
        transaction.destroy if transaction
        deleted_count += 1
      end
    end

    redirect_to financial_manage_duplicates_path,
                notice: "Removed #{deleted_count} duplicate transactions."
  end

  def clear_bank_statements
    deleted_count = current_user.bank_statements.delete_all
    redirect_to financial_path,
                notice: "Removed all #{deleted_count} bank statement transactions."
  end

  def clear_investments
    deleted_count = current_user.investments.delete_all
    redirect_to financial_path,
                notice: "Removed all #{deleted_count} investment transactions."
  end

  private

  def find_duplicate_groups
    # Find groups of potential duplicate bank statements
    # Group by date, amount, and description similarity
    # Since SQLite doesn't support ARRAY_AGG, we'll use a different approach

    duplicate_groups = current_user.bank_statements
                                  .select("date, amount, description, COUNT(*) as count")
                                  .group("date, amount, description")
                                  .having("COUNT(*) > 1")
                                  .order("date DESC")

    duplicate_groups.map do |group|
      # Find all transactions for this duplicate group
      transactions = current_user.bank_statements.where(
        date: group.date,
        amount: group.amount,
        description: group.description
      )

      {
        date: group.date,
        amount: group.amount,
        description: group.description,
        count: group.count,
        transactions: transactions
      }
    end
  end
end
