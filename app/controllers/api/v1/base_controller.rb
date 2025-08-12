class Api::V1::BaseController < ApplicationController
  before_action :authenticate_api_user!
  before_action :set_default_format
  protect_from_forgery with: :null_session
  
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
  rescue_from StandardError, with: :internal_server_error

  private

  def authenticate_api_user!
    # Try cookie-based authentication first (for web sessions)
    return if user_signed_in?
    
    # Try basic auth for API access
    authenticate_or_request_with_http_basic do |email, password|
      user = User.find_by(email: email)
      if user&.valid_password?(password)
        sign_in user
        true
      else
        false
      end
    end
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
