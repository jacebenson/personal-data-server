class Api::V1::BaseController < ApplicationController
  before_action :authenticate_api_user!
  before_action :set_default_format
  protect_from_forgery with: :null_session
  
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
  rescue_from StandardError, with: :internal_server_error

  private

  def authenticate_api_user!
    # Try cookie-based authentication first (for web sessions)
    if user_signed_in?
      Rails.logger.info "API Auth: Already signed in via session - User: #{current_user.email}"
      @authenticated_api_user = current_user
      return
    end
    
    # Try basic auth for API access
    authenticate_or_request_with_http_basic do |email, password|
      Rails.logger.info "API Auth attempt: #{email}"
      Rails.logger.info "API Auth password length: #{password&.length || 0}"
      Rails.logger.info "API Auth headers: #{request.headers['Authorization']&.first(50)}"
      
      user = User.find_by(email: email)
      if user
        Rails.logger.info "API Auth: User found - #{user.email}"
        password_valid = user.valid_password?(password)
        Rails.logger.info "API Auth: Password valid: #{password_valid}"
        
        if password_valid
          Rails.logger.info "API Auth successful for: #{email}"
          sign_in user
          # Store authenticated user in instance variable and session
          @authenticated_api_user = user
          session[:authenticated_api_user_id] = user.id
          Rails.logger.info "API Auth: @authenticated_api_user set to #{@authenticated_api_user.email}"
          return true
        else
          Rails.logger.warn "API Auth failed - invalid password for: #{email}"
          return false
        end
      else
        Rails.logger.warn "API Auth failed - user not found: #{email}"
        return false
      end
    end
    
    # If we get here, authentication failed
    Rails.logger.warn "API Auth: No authentication provided or failed"
    render json: { success: false, error: "Authentication required" }, status: :unauthorized
    false
  end
  
  # Override current_user to use our authenticated user
  def current_user
    # Return authenticated API user if available
    return @authenticated_api_user if @authenticated_api_user
    
    # Try to get from session if we have an ID stored
    if session[:authenticated_api_user_id]
      @authenticated_api_user ||= User.find_by(id: session[:authenticated_api_user_id])
      return @authenticated_api_user if @authenticated_api_user
    end
    
    # Fall back to regular Devise current_user
    super
  end

  def set_default_format
    request.format = :json unless params[:format]
  end

  def record_not_found(exception)
    render_error("Record not found: #{exception.message}", :not_found)
  end

  def internal_server_error(exception)
    Rails.logger.error "API Error: #{exception.message}"
    Rails.logger.error exception.backtrace.join("\n")
    render_error("Internal server error", :internal_server_error)
  end

  def render_success(data, message = nil)
    response = { success: true, data: data }
    response[:message] = message if message
    render json: response
  end

  def render_error(message, status = :unprocessable_entity)
    render json: { success: false, error: message }, status: status
  end

  def paginate_collection(collection, per_page = 50)
    page = params[:page]&.to_i || 1
    per_page = [params[:per_page]&.to_i || per_page, 100].min # Max 100 per page
    
    collection.page(page).per(per_page)
  end
end
