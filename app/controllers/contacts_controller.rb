class ContactsController < ApplicationController
  before_action :authenticate_user!

  def index
    # Check if we should show the contact list or upload form
    if params[:show] == 'true'
      # Show contact list (same as old view_contacts)
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
      
      render 'show'
    else
      # Show contact upload form (renders index.html.erb by default)
      # Get existing sources for the dropdown
      @existing_sources = current_user.contacts.distinct.pluck(:source).compact.sort
    end
  end

  def upload_vcard
    # Process uploaded vCard files (including zipped vcards)
    if params[:file].present?
      begin
        # Determine the source
        source = determine_source_from_params(params, 'vcard')
        
        result = VcardProcessor.new(params[:file], current_user, nil, source).process

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

        redirect_to contacts_path, notice: message
      rescue => e
        redirect_to contacts_path, alert: "Error processing vCard file: #{e.message}"
      end
    else
      redirect_to contacts_path, alert: "Please select a vCard file to upload."
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

        # LinkedIn connections always use "linkedin" as the source
        processor = LinkedinConnectionsProcessor.new(current_user, 'linkedin')
        results = processor.process_csv_file(temp_file.path)

        message = "LinkedIn import completed: #{results[:created]} new contacts created"
        if results[:updated] > 0
          message += ", #{results[:updated]} contacts updated"
        end
        message += " (#{results[:processed]} total processed)."

        if results[:errors].any?
          message += " #{results[:errors].length} errors occurred."
        end

        redirect_to contacts_path, notice: message
      rescue => e
        redirect_to contacts_path, alert: "Error processing LinkedIn CSV file: #{e.message}"
      ensure
        temp_file&.unlink # Clean up temp file
      end
    else
      redirect_to contacts_path, alert: "Please select a LinkedIn Connections CSV file to upload."
    end
  end

  def show
    # Show individual contact
    @contact = current_user.contacts.find(params[:id])
    render 'contact'
  rescue ActiveRecord::RecordNotFound
    redirect_to contacts_path(show: true), alert: "Contact not found."
  end

  def clear
    # Clear all contacts for the current user
    count = current_user.contacts.count
    current_user.contacts.destroy_all
    redirect_to contacts_path, notice: "Successfully deleted #{count} contacts."
  end

  def duplicates
    # Show potential duplicate contacts
    @merge_service = ContactMergeService.new(current_user)
    all_groups = @merge_service.find_duplicates

    # Filter to only include groups with 2 or more contacts
    @duplicate_groups = all_groups.select { |group| group.length >= 2 }
    @merge_results = @merge_service.merge_results

    # Update the results to reflect filtered groups
    @merge_results[:duplicate_groups] = @duplicate_groups.length
  end

  def merge
    # Merge specific contacts
    contact_ids = params[:contact_ids]
    redirect_path = request.referer&.include?('duplicates') ? duplicates_contacts_path : contacts_path(show: true)

    if contact_ids.blank? || contact_ids.length < 2
      redirect_to redirect_path, alert: "Please select at least 2 contacts to merge."
      return
    end

    begin
      contacts = current_user.contacts.where(id: contact_ids)

      if contacts.count != contact_ids.length
        redirect_to redirect_path, alert: "Some selected contacts were not found."
        return
      end

      merge_service = ContactMergeService.new(current_user)
      primary_contact = merge_service.merge_contact_group!(contacts.to_a)

      redirect_to contact_path(primary_contact),
                  notice: "Successfully merged #{contact_ids.length} contacts into #{primary_contact.full_name}."
    rescue => e
      redirect_to redirect_path, alert: "Error merging contacts: #{e.message}"
    end
  end

  def auto_merge
    # Handle both GET (confirmation) and POST (actual merge) requests
    if request.post?
      begin
        merge_service = ContactMergeService.new(current_user)
        results = merge_service.auto_merge_all!

        message = "Auto-merge completed: #{results[:merged_count]} contact groups merged, #{results[:contacts_merged]} total contacts merged."
        redirect_to contacts_path(show: true), notice: message
      rescue => e
        redirect_to duplicates_contacts_path, alert: "Error during auto-merge: #{e.message}"
      end
    else
      # Show confirmation page
      merge_service = ContactMergeService.new(current_user)
      @duplicate_groups = merge_service.find_duplicates
      @total_to_merge = @duplicate_groups.sum { |group| group.length - 1 }
    end
  end

  private

  def determine_source_from_params(params, default_source)
    if params[:source] == 'custom'
      params[:custom_source].present? ? params[:custom_source] : default_source
    else
      params[:source].present? ? params[:source] : default_source
    end
  end
end
