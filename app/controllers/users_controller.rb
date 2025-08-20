# frozen_string_literal: true

class UsersController < ApplicationController
  before_action :authenticate_user!

  def show
    @user = current_user
    @bearer_token = @user.bearer_token
  end

  def update
    if current_user.update(user_params)
      redirect_to user_path, notice: 'Settings updated successfully'
    else
      redirect_to user_path, alert: 'Failed to update settings'
    end
  end

  def regenerate_token
    # Since tokens are deterministic based on user attributes,
    # we can't truly regenerate without changing the password
    # Instead, we'll just refresh the display
    redirect_to user_path, notice: 'Token refreshed (tokens are deterministic based on your account data)'
  end

  private

  def user_params
    params.require(:user).permit(:setting_privacy_mode)
  end
end
