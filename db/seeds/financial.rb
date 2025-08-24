# Financial Data Seeds
# Creates sample financial data for testing and demonstration

def seed_financial_data(user)
  puts "💰 Seeding financial data for #{user.email}..."

  # Bank Statements - Sample transactions
  bank_transactions = [
    {
      date: 30.days.ago,
      description: "PAYROLL DEPOSIT",
      amount: 3500.00,
      account: "Checking",
      category: "Income"
    },
    {
      date: 29.days.ago,
      description: "GROCERY STORE",
      amount: -156.78,
      account: "Checking",
      category: "Food"
    },
    {
      date: 28.days.ago,
      description: "ELECTRIC BILL",
      amount: -89.45,
      account: "Checking",
      category: "Utilities"
    },
    {
      date: 25.days.ago,
      description: "ATM WITHDRAWAL",
      amount: -100.00,
      account: "Checking",
      category: "Cash"
    },
    {
      date: 20.days.ago,
      description: "RESTAURANT",
      amount: -45.23,
      account: "Checking",
      category: "Dining"
    },
    {
      date: 15.days.ago,
      description: "PAYROLL DEPOSIT",
      amount: 3500.00,
      account: "Checking",
      category: "Income"
    },
    {
      date: 10.days.ago,
      description: "GAS STATION",
      amount: -67.89,
      account: "Checking",
      category: "Transportation"
    },
    {
      date: 5.days.ago,
      description: "INTEREST PAYMENT",
      amount: 12.45,
      account: "Savings",
      category: "Interest"
    }
  ]

  bank_transactions.each do |transaction|
    BankStatement.find_or_create_by!(
      user: user,
      date: transaction[:date],
      description: transaction[:description],
      amount: transaction[:amount],
      account: transaction[:account]
    ) do |stmt|
      stmt.category = transaction[:category]
    end
  end

  # Investment Data
  investment_transactions = [
    {
      date: 60.days.ago,
      action: "Buy",
      symbol: "VTI",
      description: "Vanguard Total Stock Market ETF",
      investment_type: "ETF",
      quantity: 10,
      price: 245.50,
      amount: -2455.00,
      account: "401K",
      account_number: "401K-001"
    },
    {
      date: 30.days.ago,
      action: "Buy",
      symbol: "VTIAX",
      description: "Vanguard Total International Stock Index Fund",
      investment_type: "Mutual Fund",
      quantity: 5.123,
      price: 32.45,
      amount: -166.24,
      account: "IRA",
      account_number: "IRA-001"
    },
    {
      date: 15.days.ago,
      action: "Dividend",
      symbol: "VTI",
      description: "Dividend Payment",
      investment_type: "ETF",
      quantity: 0,
      price: 0,
      amount: 15.75,
      account: "401K",
      account_number: "401K-001"
    }
  ]

  investment_transactions.each do |transaction|
    Investment.find_or_create_by!(
      user: user,
      date: transaction[:date],
      action: transaction[:action],
      symbol: transaction[:symbol],
      description: transaction[:description],
      account: transaction[:account]
    ) do |inv|
      inv.investment_type = transaction[:investment_type]
      inv.quantity = transaction[:quantity]
      inv.price = transaction[:price]
      inv.amount = transaction[:amount]
      inv.account_number = transaction[:account_number]
      inv.commission = 0
      inv.fees = 0
    end
  end

  # Social Security Earnings
  current_year = Date.current.year
  (2020..current_year-1).each do |year|
    SocialSecurityEarning.find_or_create_by!(
      user: user,
      year: year
    ) do |earning|
      # Generate realistic earnings that increase over time
      base_earnings = 45000 + (year - 2020) * 2000 + rand(-3000..5000)
      earning.fica_earnings = [ base_earnings, 160200 ].min # FICA cap
      earning.medicare_earnings = base_earnings
    end
  end

  # Amazon Orders - Sample purchases
  amazon_orders = [
    {
      order_type: "retail",
      order_id: "123-4567890-1234567",
      order_date: 20.days.ago,
      asin: "B08N5WRWNW",
      product_name: "Echo Dot (4th Gen)",
      quantity: 1,
      total_owed: 49.99,
      currency_code: "USD",
      is_fulfilled: true,
      marketplace: "Amazon.com",
      order_status: "Delivered"
    },
    {
      order_type: "digital",
      order_id: "D01-2345678-9012345",
      order_date: 15.days.ago,
      digital_order_item_id: "digital-123456",
      product_name: "Kindle eBook - The Pragmatic Programmer",
      quantity: 1,
      our_price: 24.99,
      currency_code: "USD",
      is_fulfilled: true,
      marketplace: "Amazon.com",
      order_status: "Complete"
    },
    {
      order_type: "retail",
      order_id: "123-4567890-9876543",
      order_date: 10.days.ago,
      asin: "B0932BH8HH",
      product_name: "USB-C Cable 6ft",
      quantity: 2,
      total_owed: 25.98,
      currency_code: "USD",
      is_fulfilled: true,
      marketplace: "Amazon.com",
      order_status: "Delivered"
    }
  ]

  amazon_orders.each do |order|
    AmazonOrder.find_or_create_by!(
      user: user,
      order_type: order[:order_type],
      order_id: order[:order_id],
      asin: order[:asin],
      digital_order_item_id: order[:digital_order_item_id]
    ) do |amazon_order|
      amazon_order.order_date = order[:order_date]
      amazon_order.product_name = order[:product_name]
      amazon_order.quantity = order[:quantity]
      amazon_order.our_price = order[:our_price]
      amazon_order.total_owed = order[:total_owed]
      amazon_order.currency_code = order[:currency_code]
      amazon_order.is_fulfilled = order[:is_fulfilled]
      amazon_order.marketplace = order[:marketplace]
      amazon_order.order_status = order[:order_status]
      amazon_order.website = "amazon.com"
    end
  end

  puts "   ✅ Created #{BankStatement.where(user: user).count} bank transactions"
  puts "   ✅ Created #{Investment.where(user: user).count} investment transactions"
  puts "   ✅ Created #{SocialSecurityEarning.where(user: user).count} social security earnings records"
  puts "   ✅ Created #{AmazonOrder.where(user: user).count} Amazon orders"
end
