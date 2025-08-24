class Api::V1::TransactionsController < Api::V1::BaseController
  def index
    search_query = params[:q]&.downcase
    limit = (params[:limit] || 50).to_i
    
    render_success({
      amazon_orders: search_amazon_orders(search_query).limit(limit),
      bank_statements: search_bank_statements(search_query).limit(limit)
    })
  end

  private

  def search_amazon_orders(query)
    orders = current_user.amazon_orders.order(order_date: :desc)
    if query.present?
      orders = orders.where("LOWER(item_name) LIKE ? OR LOWER(order_status) LIKE ?", 
                           "%#{query}%", "%#{query}%")
    end
    
    orders.map do |order|
      {
        date: order.order_date,
        item: order.item_name,
        amount: order.item_total,
        status: order.order_status,
        quantity: order.quantity,
        category: order.category
      }
    end
  end

  def search_bank_statements(query)
    statements = current_user.bank_statements.order(date: :desc)
    if query.present?
      statements = statements.where("LOWER(description) LIKE ? OR LOWER(account) LIKE ?", 
                                   "%#{query}%", "%#{query}%")
    end
    
    statements.map do |statement|
      {
        date: statement.date,
        description: statement.description,
        amount: statement.amount,
        account: statement.account,
        transaction_type: statement.transaction_type
      }
    end
  end
end
