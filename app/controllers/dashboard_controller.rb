class DashboardController < ApplicationController
  before_action :authenticate_user!

  def index
    # Personal dashboard with overview of all data
  end
end
