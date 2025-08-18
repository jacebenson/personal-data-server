# frozen_string_literal: true

# Service to parse human-readable time expressions into date ranges
# Used by MCP endpoints to convert natural language time queries
class TimeExpressionParser
  # Map of human expressions to time ranges
  TIME_EXPRESSIONS = {
    'recent' => -> { 3.months.ago..Time.current },
    'today' => -> { Time.current.beginning_of_day..Time.current.end_of_day },
    'yesterday' => -> { 1.day.ago.beginning_of_day..1.day.ago.end_of_day },
    'this week' => -> { Time.current.beginning_of_week..Time.current.end_of_week },
    'last week' => -> { 1.week.ago.beginning_of_week..1.week.ago.end_of_week },
    'this month' => -> { Time.current.beginning_of_month..Time.current.end_of_month },
    'last month' => -> { 1.month.ago.beginning_of_month..1.month.ago.end_of_month },
    'this year' => -> { Time.current.beginning_of_year..Time.current.end_of_year },
    'last year' => -> { 1.year.ago.beginning_of_year..1.year.ago.end_of_year },
    'current' => -> { Time.current.beginning_of_day..Time.current.end_of_day },
    'all time' => -> { Time.new(2000, 1, 1)..Time.current }
  }.freeze

  class << self
    # Parse a time expression and return a date range
    # @param expression [String] Human-readable time expression
    # @return [Range<Time>] Date range
    # @raise [ArgumentError] If expression is invalid
    def parse(expression)
      return nil if expression.blank?
      
      expression = expression.to_s.strip.downcase
      
      # Check if it's a predefined expression
      if TIME_EXPRESSIONS.key?(expression)
        return TIME_EXPRESSIONS[expression].call
      end
      
      # Try to parse as a specific date
      if (date_range = parse_specific_date(expression))
        return date_range
      end
      
      # Try to parse as a year
      if (year_range = parse_year(expression))
        return year_range
      end
      
      # Try to parse relative expressions like "last 3 months"
      if (relative_range = parse_relative_expression(expression))
        return relative_range
      end
      
      # Default to "recent" if we can't parse
      Rails.logger.warn "Could not parse time expression '#{expression}', defaulting to 'recent'"
      TIME_EXPRESSIONS['recent'].call
    end
    
    # Get a human-readable description of what the time range represents
    # @param expression [String] Original expression
    # @param range [Range<Time>] Parsed date range
    # @return [String] Description
    def describe_range(expression, range)
      return "all available data" if expression == 'all time'
      return "the specified time period" if range.nil?
      
      start_date = range.begin
      end_date = range.end
      
      if start_date.to_date == end_date.to_date
        "#{start_date.strftime('%B %d, %Y')}"
      elsif start_date.year == end_date.year
        "#{start_date.strftime('%B %d')} - #{end_date.strftime('%B %d, %Y')}"
      else
        "#{start_date.strftime('%B %Y')} - #{end_date.strftime('%B %Y')}"
      end
    end
    
    # Get available time expression options for API documentation
    # @return [Array<String>] List of supported expressions
    def supported_expressions
      TIME_EXPRESSIONS.keys + [
        'YYYY (specific year)',
        'YYYY-MM-DD (specific date)', 
        'YYYY-MM-DD HH:MM (specific datetime)',
        'last X days/weeks/months/years'
      ]
    end

    private

    # Parse specific dates like "2024-01-15" or "2024-01-15 14:30"
    def parse_specific_date(expression)
      # Try ISO date format YYYY-MM-DD
      if expression.match?(/^\d{4}-\d{2}-\d{2}$/)
        date = Date.parse(expression)
        return date.beginning_of_day..date.end_of_day
      end
      
      # Try ISO datetime format YYYY-MM-DD HH:MM
      if expression.match?(/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$/)
        datetime = Time.parse(expression)
        return datetime..datetime.end_of_day
      end
      
      nil
    rescue Date::Error, ArgumentError
      nil
    end
    
    # Parse year expressions like "2024"
    def parse_year(expression)
      if expression.match?(/^\d{4}$/) && (1900..2100).cover?(expression.to_i)
        year = expression.to_i
        start_date = Time.new(year, 1, 1)
        end_date = Time.new(year, 12, 31).end_of_day
        return start_date..end_date
      end
      
      nil
    end
    
    # Parse relative expressions like "last 3 months", "past 2 weeks"
    def parse_relative_expression(expression)
      patterns = [
        /^(?:last|past)\s+(\d+)\s+(days?|weeks?|months?|years?)$/,
        /^(\d+)\s+(days?|weeks?|months?|years?)\s+ago$/
      ]
      
      patterns.each do |pattern|
        match = expression.match(pattern)
        next unless match
        
        amount = match[1].to_i
        unit = match[2].gsub(/s$/, '') # Remove plural 's'
        
        case unit
        when 'day'
          return amount.days.ago.beginning_of_day..Time.current
        when 'week'
          return amount.weeks.ago.beginning_of_week..Time.current.end_of_week
        when 'month'
          return amount.months.ago.beginning_of_month..Time.current
        when 'year'
          return amount.years.ago.beginning_of_year..Time.current
        end
      end
      
      nil
    end
  end
end
