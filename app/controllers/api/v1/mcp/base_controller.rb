# frozen_string_literal: true

# Base controller for MCP (Model Context Protocol) endpoints
# Provides common functionality and response formatting for LLM consumption
class Api::V1::Mcp::BaseController < Api::V1::BaseController
  protect_from_forgery with: :null_session
  before_action :validate_json_request
  before_action :log_mcp_request
  
  # Override parent's render methods to use MCP format
  def render_success(data, message = nil, suggested_actions = [])
    response = {
      success: true,
      action: action_name,
      result: data,
      context: message || generate_context_message(data),
      suggested_next_actions: suggested_actions,
      timestamp: Time.current.iso8601
    }
    
    render json: response
  end

  def render_error(message, status = :unprocessable_entity, suggestions = [])
    response = {
      success: false,
      action: action_name,
      error: message,
      suggestions: suggestions,
      timestamp: Time.current.iso8601
    }
    
    render json: response, status: status
  end
  
  # Render validation errors in MCP format
  def render_validation_errors(errors, suggestions = [])
    error_messages = if errors.respond_to?(:full_messages)
                      errors.full_messages.join(', ')
                    else
                      errors.to_s
                    end
    
    render_error("Validation failed: #{error_messages}", :bad_request, suggestions)
  end

  protected

  # Override current_user to ensure we get the authenticated user from parent
  def current_user
    # First try the parent's current_user method
    parent_user = super
    
    if parent_user
      @current_user = parent_user
      return @current_user
    end
    
    nil
  end

  # Parse time expressions using TimeExpressionParser
  def parse_timeframe(timeframe_param)
    return nil if timeframe_param.blank?
    
    TimeExpressionParser.parse(timeframe_param)
  rescue ArgumentError => e
    Rails.logger.warn "Invalid timeframe '#{timeframe_param}': #{e.message}"
    nil
  end
  
  # Get a description of the parsed timeframe
  def describe_timeframe(expression, range)
    TimeExpressionParser.describe_range(expression, range)
  end
  
  # Validate that required parameters are present
  def validate_required_params(*param_names)
    missing_params = param_names.select { |param| params[param].blank? }
    
    if missing_params.any?
      suggestions = ["Provide values for: #{missing_params.join(', ')}"]
      render_error("Missing required parameters: #{missing_params.join(', ')}", :bad_request, suggestions)
      return false
    end
    
    true
  end
  
  # Sanitize and validate data types for common parameters
  def sanitize_params
    @sanitized_params = {}
    
    # Permit all potentially relevant parameters including nested search parameters
    permitted_params = params.permit(:timeframe, :limit, :query, :include_history, :include_forecasts, :include_context, :include_recommendations,
                                   data_types: [], categories: [], sources: [], metrics: [],
                                   search: [:timeframe, :limit, :query, :include_history, :include_forecasts, :include_context, :include_recommendations,
                                           data_types: [], categories: [], sources: [], metrics: []])
    
    # Check if parameters are nested under :search key (common with JSON requests)
    if permitted_params[:search].present?
      nested_params = permitted_params[:search]
    else
      nested_params = permitted_params
    end
    
    # Handle timeframe
    if nested_params[:timeframe].present?
      @sanitized_params[:timeframe] = nested_params[:timeframe].to_s.strip
      @sanitized_params[:parsed_timeframe] = parse_timeframe(@sanitized_params[:timeframe])
    end
    
    # Handle limit
    if nested_params[:limit].present?
      limit = nested_params[:limit].to_i
      @sanitized_params[:limit] = limit.positive? ? [limit, 1000].min : 50 # Cap at 1000, default 50
    else
      @sanitized_params[:limit] = 50
    end
    
    # Handle query/search terms
    if nested_params[:query].present?
      @sanitized_params[:query] = nested_params[:query].to_s.strip
    end
    
    # Handle arrays (data_types, categories, etc.)
    %w[data_types categories sources metrics].each do |array_param|
      if nested_params[array_param].present?
        @sanitized_params[array_param.to_sym] = Array(nested_params[array_param]).map(&:to_s).map(&:strip).reject(&:blank?)
      end
    end
    
    # Handle boolean flags
    %w[include_history include_forecasts include_context include_recommendations].each do |bool_param|
      if nested_params[bool_param].present?
        @sanitized_params[bool_param.to_sym] = ActiveModel::Type::Boolean.new.cast(nested_params[bool_param])
      end
    end
  end

  private

  # Ensure request is JSON
  def validate_json_request
    unless request.content_type&.include?('application/json')
      render_error("Content-Type must be application/json", :unsupported_media_type, 
                   ["Set Content-Type header to 'application/json'"])
      return false
    end
    
    sanitize_params
    true
  rescue JSON::ParserError
    render_error("Invalid JSON in request body", :bad_request, 
                 ["Ensure request body contains valid JSON"])
    false
  end
  
  # Log MCP API requests for monitoring and analytics
  def log_mcp_request
    Rails.logger.info "MCP API Request: #{controller_name}##{action_name} - User: #{current_user&.email} - Params: #{filtered_params}"
  end
  
  # Filter sensitive parameters from logs
  def filtered_params
    begin
      # Try to get permitted parameters safely
      safe_params = params.except(:controller, :action, :format)
      safe_params.permit!.to_h
    rescue ActionController::UnpermittedParameters
      # If we can't convert to hash, just return the parameter keys
      params.except(:controller, :action, :format).keys
    end
  end
  
  # Generate contextual message based on the data returned
  def generate_context_message(data)
    case data
    when Hash
      if data[:total_matches]
        "Found #{data[:total_matches]} matches"
      elsif data.key?(:results) && data[:results].respond_to?(:count)
        "Retrieved #{data[:results].count} items"
      else
        "Operation completed successfully"
      end
    when Array
      "Retrieved #{data.count} items"
    when ActiveRecord::Relation
      "Retrieved #{data.count} items"
    else
      "Operation completed successfully"
    end
  end
  
  # Common error handling for MCP endpoints
  rescue_from ActiveRecord::RecordNotFound do |exception|
    render_error("Record not found: #{exception.message}", :not_found, 
                 ["Check that the requested resource exists", "Verify your search parameters"])
  end
  
  rescue_from ActionController::ParameterMissing do |exception|
    render_error("Missing required parameter: #{exception.param}", :bad_request,
                 ["Include the required parameter in your request", "Check API documentation for required parameters"])
  end
  
  rescue_from ActionController::UnpermittedParameters do |exception|
    render_error("Invalid parameters: #{exception.params.join(', ')}", :bad_request,
                 ["Remove invalid parameters from your request", "Check API documentation for valid parameters"])
  end
  
  rescue_from NoMethodError do |exception|
    if exception.message.include?("for nil")
      render_error("Authentication required - user not found", :unauthorized,
                   ["Ensure you are properly authenticated", "Check your authentication credentials"])
    else
      render_error("Method error: #{exception.message}", :internal_server_error,
                   ["Contact support if this error persists"])
    end
  end

  rescue_from ArgumentError do |exception|
    render_error("Invalid argument: #{exception.message}", :bad_request,
                 ["Check your parameter values", "Refer to API documentation for valid options"])
  end
  
  rescue_from StandardError do |exception|
    Rails.logger.error "MCP API Error in #{controller_name}##{action_name}: #{exception.message}"
    Rails.logger.error exception.backtrace.join("\n")
    
    render_error("An unexpected error occurred", :internal_server_error,
                 ["Try again later", "Contact support if the problem persists"])
  end
end
