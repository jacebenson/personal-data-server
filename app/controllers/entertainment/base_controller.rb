class Entertainment::BaseController < ApplicationController
  before_action :authenticate_user!

  private

  def calculate_estimated_watch_time
    # This is a rough estimate - could be enhanced with actual runtime data
    # Assuming average content is 45 minutes (mix of movies and TV episodes)
    current_user.entertainment_contents.netflix.count * 45
  end

  def calculate_total_listening_time
    # Calculate total listening time from Audible metadata in minutes
    total_ms = 0
    current_user.entertainment_contents.audible_books.each do |record|
      metadata = record.parsed_metadata
      if metadata['event_duration_ms']
        total_ms += metadata['event_duration_ms']
      end
    end
    total_ms / (1000 * 60) # Convert milliseconds to minutes
  end

  def calculate_filtered_listening_time(audible_scope)
    # Calculate total listening time from filtered Audible records in minutes
    total_ms = 0
    audible_scope.each do |record|
      metadata = record.parsed_metadata
      if metadata['event_duration_ms']
        total_ms += metadata['event_duration_ms']
      end
    end
    total_ms / (1000 * 60) # Convert milliseconds to minutes
  end
end
