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

  # Communication methods
  def communications
    # Combined communication upload page for MBOX, LinkedIn messages, and Discord
  end

  def upload_mbox
    # Process uploaded MBOX files
    if params[:file].present?
      begin
        uploaded_file = params[:file]
        file_size = uploaded_file.size

        # For files larger than 50MB, process in background
        if file_size > 50.megabytes
          # Save the uploaded file to a temporary location
          temp_dir = Rails.root.join("tmp", "mbox_uploads")
          FileUtils.mkdir_p(temp_dir)

          temp_filename = "#{current_user.id}_#{Time.current.to_i}_#{uploaded_file.original_filename}"
          temp_path = temp_dir.join(temp_filename)

          # Copy uploaded file to temp location
          File.open(temp_path, "wb") do |file|
            file.write(uploaded_file.read)
          end

          # Queue background job
          MboxProcessingJob.perform_later(temp_path.to_s, current_user.id, uploaded_file.original_filename)

          redirect_to communications_data_uploads_path,
                      notice: "Large MBOX file (#{file_size / 1.megabyte}MB) queued for background processing. You'll be notified when complete."
        else
          # Process smaller files immediately
          result = MboxProcessor.new(uploaded_file, current_user).process

          message = "Successfully imported #{result[:count]} email messages."
          if result[:skipped] && result[:skipped] > 0
            message += " Skipped #{result[:skipped]} records"
            if result[:duplicates] && result[:duplicates] > 0
              message += " (#{result[:duplicates]} duplicates)"
            end
            message += "."
          end

          if result[:errors] && result[:errors].any?
            message += " Note: #{result[:errors].length} messages had processing errors."
          end

          redirect_to communications_data_uploads_path, notice: message
        end
      rescue => e
        redirect_to communications_data_uploads_path, alert: "Error processing MBOX file: #{e.message}"
      end
    else
      redirect_to communications_data_uploads_path, alert: "Please select an MBOX file to upload."
    end
  end

  def upload_linkedin_messages
    # Process uploaded LinkedIn messages CSV
    if params[:file].present?
      begin
        result = LinkedinMessagesProcessor.new(params[:file], current_user).process

        if result[:errors].any?
          error_message = "Errors occurred during import: #{result[:errors].join(', ')}"
          redirect_to communications_data_uploads_path, alert: error_message
        else
          message = "Successfully imported #{result[:imported]} LinkedIn messages."
          if result[:skipped] > 0
            message += " Skipped #{result[:skipped]} records"
            if result[:duplicates] > 0
              message += " (#{result[:duplicates]} duplicates)"
            end
            message += "."
          end
          redirect_to communications_data_uploads_path, notice: message
        end
      rescue => e
        redirect_to communications_data_uploads_path, alert: "Error processing LinkedIn messages file: #{e.message}"
      end
    else
      redirect_to communications_data_uploads_path, alert: "Please select a LinkedIn messages CSV file to upload."
    end
  end

  def view_communications
    # Show imported communication records
    page = params[:page].to_i
    page = 1 if page < 1
    per_page = 50
    offset = (page - 1) * per_page

    # Determine which type of messages to show
    @message_type = params[:type] || 'email'

    if @message_type == 'linkedin'
      # LinkedIn messages
      linkedin_scope = current_user.linkedin_messages
      linkedin_scope = linkedin_scope.by_folder(params[:folder]) if params[:folder].present?

      @linkedin_messages = linkedin_scope.recent.limit(per_page).offset(offset)
      @total_count = linkedin_scope.count
    else
      # Email messages (default)
      @message_type = 'email'
      messages_scope = current_user.email_messages
      messages_scope = messages_scope.by_folder(params[:folder]) if params[:folder].present?

      @email_messages = messages_scope.recent.limit(per_page).offset(offset)
      @total_count = messages_scope.count
    end

    @current_page = page
    @total_pages = (@total_count.to_f / per_page).ceil
    @has_next = page < @total_pages
    @has_prev = page > 1
    @filtered_folder = params[:folder]

    # Statistics for both message types
    @total_email_messages = current_user.email_messages.count
    @total_linkedin_messages = current_user.linkedin_messages.count
    @total_size = current_user.email_messages.sum(:message_size)
    @total_messages = @message_type == 'linkedin' ? @total_linkedin_messages : @total_email_messages

    # Folders for current message type
    if @message_type == 'linkedin'
      @folders = current_user.linkedin_messages.group(:folder).count.sort_by { |folder, count| -count }
      @top_participants = current_user.linkedin_messages
                                     .group(:from_name)
                                     .order(Arel.sql("COUNT(*) DESC"))
                                     .limit(10)
                                     .count
      @date_range = {
        earliest: current_user.linkedin_messages.minimum(:sent_at),
        latest: current_user.linkedin_messages.maximum(:sent_at)
      }
    else
      @folders = current_user.email_messages.group(:folder).count.sort_by { |folder, count| -count }
      @top_senders = current_user.email_messages
                                 .group(:sender_email)
                                 .order(Arel.sql("COUNT(*) DESC"))
                                 .limit(10)
                                 .count
      @date_range = {
        earliest: current_user.email_messages.minimum(:received_date),
        latest: current_user.email_messages.maximum(:received_date)
      }
    end
  end

  def show_communication
    # Show individual email message
    @email_message = current_user.email_messages.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to view_communications_data_uploads_path, alert: "Email message not found."
  end

  def clear_communications
    # Clear all communication records for the current user
    count = current_user.email_messages.count
    current_user.email_messages.destroy_all
    redirect_to communications_data_uploads_path, notice: "Successfully deleted #{count} email messages."
  end

  # Calendar methods
  def calendars
    # Combined calendar upload page for ICS files and URLs
  end

  def upload_ics_file
    # Process uploaded ICS file
    if params[:file].present?
      begin
        result = IcsProcessor.new(params[:file], current_user).process

        message = "Successfully imported #{result[:count]} calendar events"
        message += " from #{result[:calendar_name]}" if result[:calendar_name]
        message += "."

        if result[:skipped] && result[:skipped] > 0
          message += " Skipped #{result[:skipped]} records"
          if result[:duplicates] && result[:duplicates] > 0
            message += " (#{result[:duplicates]} duplicates)"
          end
          message += "."
        end

        if result[:errors] && result[:errors].any?
          message += " Note: #{result[:errors].length} events had processing errors."
        end

        redirect_to calendars_data_uploads_path, notice: message
      rescue => e
        redirect_to calendars_data_uploads_path, alert: "Error processing ICS file: #{e.message}"
      end
    else
      redirect_to calendars_data_uploads_path, alert: "Please select an ICS file to upload."
    end
  end

  def add_ics_url
    # Process ICS URL for live sync
    if params[:ics_url].present?
      begin
        url = params[:ics_url].strip

        # Validate URL format
        uri = URI.parse(url)
        unless %w[http https].include?(uri.scheme)
          redirect_to calendars_data_uploads_path, alert: "Please provide a valid HTTP/HTTPS URL."
          return
        end

        result = IcsProcessor.new(url, current_user).process

        message = "Successfully imported #{result[:count]} calendar events from URL"
        message += " (#{result[:calendar_name]})" if result[:calendar_name]
        message += "."

        if result[:skipped] && result[:skipped] > 0
          message += " Skipped #{result[:skipped]} records"
          if result[:duplicates] && result[:duplicates] > 0
            message += " (#{result[:duplicates]} duplicates)"
          end
          message += "."
        end

        if result[:errors] && result[:errors].any?
          message += " Note: #{result[:errors].length} events had processing errors."
        end

        redirect_to calendars_data_uploads_path, notice: message
      rescue => e
        redirect_to calendars_data_uploads_path, alert: "Error processing ICS URL: #{e.message}"
      end
    else
      redirect_to calendars_data_uploads_path, alert: "Please provide an ICS URL."
    end
  end

  def view_calendars
    # Show imported calendar events
    page = params[:page].to_i
    page = 1 if page < 1
    per_page = 50
    offset = (page - 1) * per_page

    # Filter by calendar if specified
    events_scope = current_user.calendar_events
    events_scope = events_scope.by_calendar(params[:calendar]) if params[:calendar].present?

    # Time filter
    case params[:time_filter]
    when "upcoming"
      events_scope = events_scope.upcoming
    when "past"
      events_scope = events_scope.past
    when "today"
      events_scope = events_scope.today
    when "this_week"
      events_scope = events_scope.this_week
    when "this_month"
      events_scope = events_scope.this_month
    end

    @calendar_events = events_scope.chronological.limit(per_page).offset(offset)
    @total_count = events_scope.count
    @current_page = page
    @total_pages = (@total_count.to_f / per_page).ceil
    @has_next = page < @total_pages
    @has_prev = page > 1
    @filtered_calendar = params[:calendar]
    @time_filter = params[:time_filter]

    # Statistics
    @total_events = current_user.calendar_events.count
    @upcoming_events = current_user.calendar_events.upcoming_count
    @calendars = current_user.calendar_events.events_by_calendar.sort_by { |calendar, count| -count }
    @date_range = current_user.calendar_events.date_range
    @events_this_month = current_user.calendar_events.events_this_month_count
    @busiest_day = current_user.calendar_events.busiest_day_this_month
  end

  def show_calendar_event
    # Show individual calendar event
    @calendar_event = current_user.calendar_events.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to view_calendars_data_uploads_path, alert: "Calendar event not found."
  end

  def clear_calendars
    # Clear all calendar events for the current user
    count = current_user.calendar_events.count
    current_user.calendar_events.destroy_all
    redirect_to calendars_data_uploads_path, notice: "Successfully deleted #{count} calendar events."
  end

  def remove_calendar
    # Remove all events from a specific calendar
    calendar_name = params[:calendar_name]

    if calendar_name.blank?
      redirect_to view_calendars_data_uploads_path, alert: "No calendar specified."
      return
    end

    deleted_count = current_user.calendar_events.where(calendar_name: calendar_name).delete_all

    redirect_to view_calendars_data_uploads_path,
                notice: "Removed #{deleted_count} events from '#{calendar_name}' calendar."
  end

  # Contact methods
  def contacts
    # Show contact upload form
  end

  def upload_vcard
    # Process uploaded vCard files (including zipped vcards)
    if params[:file].present?
      begin
        result = VcardProcessor.new(params[:file], current_user).process

        message = "Successfully imported #{result[:count]} contacts."
        if result[:skipped] && result[:skipped] > 0
          message += " Skipped #{result[:skipped]} records"
          if result[:duplicates] && result[:duplicates] > 0
            message += " (#{result[:duplicates]} duplicates)"
          end
          message += "."
        end

        if result[:warnings] && result[:warnings].any?
          message += " Note: #{result[:warnings].length} warnings occurred."
        end

        redirect_to data_uploads_path, notice: message
      rescue => e
        redirect_to contacts_data_uploads_path, alert: "Error processing vCard file: #{e.message}"
      end
    else
      redirect_to contacts_data_uploads_path, alert: "Please select a vCard file to upload."
    end
  end

  def upload_linkedin_connections
    # Process uploaded LinkedIn Connections CSV file
    if params[:file].present?
      begin
        # Create a temporary file to work with
        temp_file = Tempfile.new([ "linkedin_connections", ".csv" ])
        temp_file.binmode
        temp_file.write(params[:file].read)
        temp_file.close

        processor = LinkedinConnectionsProcessor.new(current_user)
        results = processor.process_csv_file(temp_file.path)

        message = "LinkedIn import completed: #{results[:created]} new contacts created"
        if results[:updated] > 0
          message += ", #{results[:updated]} contacts updated"
        end
        message += " (#{results[:processed]} total processed)."

        if results[:errors].any?
          message += " #{results[:errors].length} errors occurred."
        end

        redirect_to view_contacts_data_uploads_path, notice: message
      rescue => e
        redirect_to contacts_data_uploads_path, alert: "Error processing LinkedIn CSV file: #{e.message}"
      ensure
        temp_file&.unlink # Clean up temp file
      end
    else
      redirect_to contacts_data_uploads_path, alert: "Please select a LinkedIn Connections CSV file to upload."
    end
  end

  def view_contacts
    # Show imported contacts
    page = params[:page].to_i
    page = 1 if page < 1
    per_page = 50
    offset = (page - 1) * per_page

    # Filter by source if specified
    contacts_scope = current_user.contacts
    contacts_scope = contacts_scope.by_source(params[:source]) if params[:source].present?

    # Search functionality
    contacts_scope = contacts_scope.search(params[:search]) if params[:search].present?

    @contacts = contacts_scope.alphabetical.limit(per_page).offset(offset)
    @total_count = contacts_scope.count
    @current_page = page
    @total_pages = (@total_count.to_f / per_page).ceil
    @has_next = page < @total_pages
    @has_prev = page > 1
    @filtered_source = params[:source]
    @search_term = params[:search]

    # Statistics
    @total_contacts = current_user.contacts.count
    @sources = current_user.contacts.group(:source).count.sort_by { |source, count| -count }
    @organizations = current_user.contacts.where.not(organization: [ nil, "" ]).group(:organization).count.sort_by { |org, count| -count }.first(10)
  end

  def show_contact
    # Show individual contact
    @contact = current_user.contacts.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to view_contacts_data_uploads_path, alert: "Contact not found."
  end

  def clear_contacts
    # Clear all contacts for the current user
    count = current_user.contacts.count
    current_user.contacts.destroy_all
    redirect_to contacts_data_uploads_path, notice: "Successfully deleted #{count} contacts."
  end

  def contact_duplicates
    # Show potential duplicate contacts
    @merge_service = ContactMergeService.new(current_user)
    all_groups = @merge_service.find_duplicates

    # Filter to only include groups with 2 or more contacts
    @duplicate_groups = all_groups.select { |group| group.length >= 2 }
    @merge_results = @merge_service.merge_results

    # Update the results to reflect filtered groups
    @merge_results[:duplicate_groups] = @duplicate_groups.length
  end

  def merge_contacts
    # Merge specific contacts
    contact_ids = params[:contact_ids]

    if contact_ids.blank? || contact_ids.length < 2
      redirect_to contact_duplicates_data_uploads_path, alert: "Please select at least 2 contacts to merge."
      return
    end

    begin
      contacts = current_user.contacts.where(id: contact_ids)

      if contacts.count != contact_ids.length
        redirect_to contact_duplicates_data_uploads_path, alert: "Some selected contacts were not found."
        return
      end

      merge_service = ContactMergeService.new(current_user)
      primary_contact = merge_service.merge_contact_group!(contacts.to_a)

      redirect_to show_contact_data_uploads_path(primary_contact),
                  notice: "Successfully merged #{contact_ids.length} contacts into #{primary_contact.full_name}."
    rescue => e
      redirect_to contact_duplicates_data_uploads_path, alert: "Error merging contacts: #{e.message}"
    end
  end

  def auto_merge_contacts
    # Handle both GET (confirmation) and POST (actual merge) requests
    if request.get?
      # For GET requests, redirect to the duplicates page for confirmation
      redirect_to contact_duplicates_data_uploads_path
    else
      # For POST requests, automatically merge all duplicate contacts
      begin
        merge_service = ContactMergeService.new(current_user)
        results = merge_service.auto_merge_all!

        message = "Auto-merge completed: #{results[:contacts_merged]} groups merged, #{results[:contacts_removed]} duplicate contacts removed."

        if results[:errors].any?
          message += " #{results[:errors].length} errors occurred."
        end

        redirect_to view_contacts_data_uploads_path, notice: message
      rescue => e
        redirect_to contact_duplicates_data_uploads_path, alert: "Error during auto-merge: #{e.message}"
      end
    end
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
