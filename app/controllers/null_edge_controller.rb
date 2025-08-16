class NullEdgeController < ApplicationController
  before_action :authenticate_user!

  def index
    # Show nullEDGE overview and upload form
    @total_records = current_user.null_edge_attendees.count
    @latest_record = current_user.null_edge_attendees.recent.first
    @this_year_records = current_user.null_edge_attendees.this_year.count
    @this_month_records = current_user.null_edge_attendees.this_month.count
    @last_fetch = current_user.null_edge_attendees.maximum(:created_at)
  end

  def fetch_attendees
    # Fetch current attendee count from nullEDGE website
    begin
      require 'net/http'
      require 'uri'

      uri = URI('https://events.ringcentral.com/events/nulledge')
      response = Net::HTTP.get_response(uri)
      
      if response.code == '200'
        body = response.body
        
        # Look for pattern like ">100 People are registered<"
        match = body.match(/>(\d+)\s+People\s+are\s+registered</i)
        
        if match
          attendee_count = match[1].to_i
          today = Date.current
          
          # Find or create record for today
          attendee_record = current_user.null_edge_attendees.find_or_initialize_by(date: today)
          attendee_record.count = attendee_count
          
          if attendee_record.save
            if attendee_record.previously_new_record?
              redirect_to null_edge_index_path, notice: "Successfully fetched #{attendee_count} attendees for #{today.strftime('%B %d, %Y')}"
            else
              redirect_to null_edge_index_path, notice: "Updated attendee count to #{attendee_count} for #{today.strftime('%B %d, %Y')}"
            end
          else
            redirect_to null_edge_index_path, alert: "Error saving attendee data: #{attendee_record.errors.full_messages.join(', ')}"
          end
        else
          redirect_to null_edge_index_path, alert: "Could not find attendee count in the page content. The page format may have changed."
        end
      else
        redirect_to null_edge_index_path, alert: "Error fetching nullEDGE page: HTTP #{response.code}"
      end
    rescue => e
      redirect_to null_edge_index_path, alert: "Error fetching attendee count: #{e.message}"
    end
  end

  def view
    # Show attendee history
    page = params[:page].to_i
    page = 1 if page < 1
    per_page = 50
    offset = (page - 1) * per_page

    # Date range filtering
    attendees_scope = current_user.null_edge_attendees
    
    if params[:start_date].present? && params[:end_date].present?
      begin
        start_date = Date.parse(params[:start_date])
        end_date = Date.parse(params[:end_date])
        attendees_scope = attendees_scope.by_date_range(start_date, end_date)
      rescue ArgumentError
        # Invalid date format, ignore filter
      end
    end

    @attendee_records = attendees_scope.recent.limit(per_page).offset(offset)
    @total_count = attendees_scope.count
    @current_page = page
    @total_pages = (@total_count.to_f / per_page).ceil
    @has_next = page < @total_pages
    @has_prev = page > 1
    
    # Filter parameters for forms/links
    @start_date = params[:start_date]
    @end_date = params[:end_date]
    
    # Stats
    @max_attendees = attendees_scope.maximum(:count) || 0
    @min_attendees = attendees_scope.minimum(:count) || 0
    @avg_attendees = attendees_scope.average(:count)&.round || 0
  end

  def clear
    # Clear all nullEDGE attendee records for the current user
    count = current_user.null_edge_attendees.count
    current_user.null_edge_attendees.destroy_all
    redirect_to null_edge_index_path, notice: "Successfully deleted #{count} nullEDGE attendee records."
  end
end
