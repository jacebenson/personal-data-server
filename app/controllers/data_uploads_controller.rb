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

  def transactions
    # Show transaction upload form
  end

  def process_transactions
    # Process uploaded transaction CSV
    if params[:file].present?
      begin
        result = TransactionProcessor.new(params[:file], current_user).process
        redirect_to data_uploads_path, notice: "Successfully imported #{result[:count]} transaction records."
      rescue => e
        redirect_to transactions_data_uploads_path, alert: "Error processing file: #{e.message}"
      end
    else
      redirect_to transactions_data_uploads_path, alert: "Please select a file to upload."
    end
  end

  def manage_duplicates
    # Find any remaining duplicates (shouldn't be any after migration, but just in case)
    @duplicates = current_user.bank_statements
                             .select("date, amount, description, account, COUNT(*) as count, GROUP_CONCAT(id) as ids")
                             .group(:date, :amount, :description, :account)
                             .having("COUNT(*) > 1")
  end

  def remove_duplicates
    # Remove duplicates, keeping the first occurrence
    current_user.bank_statements.where(
      "id NOT IN (SELECT MIN(id) FROM bank_statements GROUP BY user_id, date, amount, description, account)"
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
end
