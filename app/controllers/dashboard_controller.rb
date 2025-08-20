class DashboardController < ApplicationController
  before_action :authenticate_user!

  def index
    # Personal dashboard with overview of all data
    # Check URL parameter first, then fall back to user setting
    @privacy_mode = if params[:privacy].present?
                      params[:privacy] == 'true'
                    else
                      current_user.setting_privacy_mode
                    end
  end
end
