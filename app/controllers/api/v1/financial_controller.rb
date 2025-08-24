class Api::V1::FinancialController < Api::V1::BaseController
  def index
    summary = build_financial_summary
    categories = build_financial_categories

    render_success({
      summary: summary,
      categories: categories,
      last_updated: most_recent_update
    })
  end

  def bank_statements
    statements = current_user.bank_statements.order(:date)

    render_success({
      category: 'bank_statements',
      count: statements.count,
      date_range: date_range_for(statements, :date),
      total_amount: statements.sum(:amount),
      items: statements.map { |stmt| bank_statement_data(stmt) }
    })
  end

  def investments
    investments = current_user.investments.order(:date)

    render_success({
      category: 'investments',
      count: investments.count,
      date_range: date_range_for(investments, :date),
      total_amount: investments.sum(:amount),
      items: investments.map { |inv| investment_data(inv) }
    })
  end

  def social_security_earnings
    earnings = current_user.social_security_earnings.order(:year)

    render_success({
      category: 'social_security_earnings',
      count: earnings.count,
      year_range: {
        earliest: earnings.minimum(:year),
        latest: earnings.maximum(:year)
      },
      total_earnings: earnings.sum(:medicare_earnings),
      items: earnings.map { |earning| ssa_earning_data(earning) }
    })
  end

  def amazon_orders
    orders = current_user.amazon_orders.order(:order_date)

    render_success({
      category: 'amazon_orders',
      count: orders.count,
      date_range: date_range_for(orders, :order_date),
      total_spent: orders.sum(:total_owed),
      items: orders.map { |order| amazon_order_data(order) }
    })
  end

  private

  def build_financial_summary
    {
      bank_statements_count: current_user.bank_statements.count,
      investments_count: current_user.investments.count,
      ssa_earnings_count: current_user.social_security_earnings.count,
      amazon_orders_count: current_user.amazon_orders.count,
      total_bank_amount: current_user.bank_statements.sum(:amount),
      total_investment_amount: current_user.investments.sum(:amount),
      total_amazon_spent: current_user.amazon_orders.sum(:total_owed)
    }
  end

  def build_financial_categories
    [
      {
        name: 'bank_statements',
        count: current_user.bank_statements.count,
        endpoint: '/api/v1/financial/bank_statements',
        total_amount: current_user.bank_statements.sum(:amount)
      },
      {
        name: 'investments',
        count: current_user.investments.count,
        endpoint: '/api/v1/financial/investments',
        total_amount: current_user.investments.sum(:amount)
      },
      {
        name: 'social_security_earnings',
        count: current_user.social_security_earnings.count,
        endpoint: '/api/v1/financial/social_security_earnings',
        total_earnings: current_user.social_security_earnings.sum(:medicare_earnings)
      },
      {
        name: 'amazon_orders',
        count: current_user.amazon_orders.count,
        endpoint: '/api/v1/financial/amazon_orders',
        total_spent: current_user.amazon_orders.sum(:total_owed)
      }
    ]
  end

  def most_recent_update
    [
      current_user.bank_statements.maximum(:updated_at),
      current_user.investments.maximum(:updated_at),
      current_user.social_security_earnings.maximum(:updated_at),
      current_user.amazon_orders.maximum(:updated_at)
    ].compact.max
  end

  def date_range_for(collection, date_field)
    {
      earliest: collection.minimum(date_field),
      latest: collection.maximum(date_field)
    }
  end

  def bank_statement_data(statement)
    {
      id: statement.id,
      date: statement.date,
      description: statement.description,
      amount: statement.amount,
      account: statement.account,
      category: statement.category
    }
  end

  def investment_data(investment)
    {
      id: investment.id,
      date: investment.date,
      account: investment.account,
      symbol: investment.symbol,
      description: investment.description,
      quantity: investment.quantity,
      price: investment.price,
      amount: investment.amount,
      investment_type: investment.investment_type,
      action: investment.action
    }
  end

  def ssa_earning_data(earning)
    {
      id: earning.id,
      year: earning.year,
      fica_earnings: earning.fica_earnings,
      medicare_earnings: earning.medicare_earnings
    }
  end

  def amazon_order_data(order)
    {
      id: order.id,
      order_date: order.order_date,
      order_id: order.order_id,
      title: order.title,
      category: order.category,
      asin: order.asin,
      unspsc_code: order.unspsc_code,
      website: order.website,
      release_date: order.release_date,
      condition: order.condition,
      seller: order.seller,
      seller_credentials: order.seller_credentials,
      list_price_per_unit: order.list_price_per_unit,
      purchase_price_per_unit: order.purchase_price_per_unit,
      quantity: order.quantity,
      payment_instrument_type: order.payment_instrument_type,
      purchase_order_number: order.purchase_order_number,
      po_line_number: order.po_line_number,
      ordering_customer_email: order.ordering_customer_email,
      shipment_date: order.shipment_date,
      shipping_address_name: order.shipping_address_name,
      shipping_address_street1: order.shipping_address_street1,
      shipping_address_street2: order.shipping_address_street2,
      shipping_address_city: order.shipping_address_city,
      shipping_address_state: order.shipping_address_state,
      shipping_address_zip: order.shipping_address_zip,
      order_status: order.order_status,
      carrier_name_tracking_number: order.carrier_name_tracking_number,
      product_name: order.product_name,
      gift_message: order.gift_message,
      gift_sender_name: order.gift_sender_name,
      gift_recipient_contact_details: order.gift_recipient_contact_details,
      total_charged: order.total_charged,
      total_promotions: order.total_promotions,
      order_total: order.order_total
    }
  end
end
