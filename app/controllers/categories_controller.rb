class CategoriesController < ApplicationController
  before_action :authenticate_user!

  def financial
    @bank_statements_count = current_user.bank_statements.count
    @investments_count = current_user.investments.count
    @ssa_earnings_count = current_user.social_security_earnings.count
    @amazon_orders_count = current_user.amazon_orders.count

    @last_bank_upload = current_user.bank_statements.maximum(:created_at)
    @last_investment_upload = current_user.investments.maximum(:created_at)
    @last_ssa_upload = current_user.social_security_earnings.maximum(:created_at)
    @last_amazon_upload = current_user.amazon_orders.maximum(:created_at)
  end

  def personal
    # Placeholder for future personal data counts
    @communications_count = current_user.email_messages.count
    @health_records_count = 0
    @contacts_count = 0
    @calendar_events_count = 0
    @content_items_count = 0
  end
end
