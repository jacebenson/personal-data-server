# frozen_string_literal: true

# MCP Financial Controller - handles financial summaries and spending analysis
class Api::V1::Mcp::FinancialController < Api::V1::Mcp::BaseController
  
  # Get comprehensive financial overview
  # POST /api/v1/mcp/get_financial_summary
  def get_financial_summary
    timeframe = @sanitized_params[:parsed_timeframe] || TimeExpressionParser.parse('recent')
    include_forecasts = @sanitized_params[:include_forecasts] || false
    categories = @sanitized_params[:categories] || %w[savings spending investments]
    
    summary_data = {}
    
    # Include savings information
    if categories.include?('savings')
      summary_data[:savings] = calculate_savings_summary(timeframe)
    end
    
    # Include spending information
    if categories.include?('spending')
      summary_data[:spending] = calculate_spending_summary(timeframe)
    end
    
    # Include investment information
    if categories.include?('investments')
      summary_data[:investments] = calculate_investment_summary(timeframe)
    end
    
    # Add forecasts if requested
    if include_forecasts
      summary_data[:forecasts] = generate_financial_forecasts(summary_data)
    end
    
    response_data = {
      timeframe: @sanitized_params[:timeframe] || 'recent',
      categories: categories,
      include_forecasts: include_forecasts,
      summary: summary_data,
      generated_at: Time.current
    }
    
    context_message = build_financial_summary_context(summary_data, timeframe)
    suggested_actions = ['analyze_spending_pattern', 'calculate_savings_potential']
    
    render_success(response_data, context_message, suggested_actions)
  end
  
  # Deep dive into spending habits
  # POST /api/v1/mcp/analyze_spending_pattern
  def analyze_spending_pattern
    category = params[:category]
    timeframe = @sanitized_params[:parsed_timeframe] || TimeExpressionParser.parse('last month')
    compare_to_timeframe = parse_comparison_timeframe(params[:compare_to])
    
    # Get spending data for the requested timeframe
    current_spending = analyze_spending_for_period(category, timeframe)
    
    # Get comparison data if requested
    comparison_spending = nil
    if compare_to_timeframe
      comparison_spending = analyze_spending_for_period(category, compare_to_timeframe)
    end
    
    # Calculate trends and insights
    insights = generate_spending_insights(current_spending, comparison_spending, category)
    
    response_data = {
      category: category,
      timeframe: @sanitized_params[:timeframe] || 'last month',
      compare_to: params[:compare_to],
      current_period: current_spending,
      comparison_period: comparison_spending,
      insights: insights
    }
    
    context_message = build_spending_analysis_context(category, current_spending, comparison_spending)
    suggested_actions = ['calculate_savings_potential', 'get_financial_summary']
    
    render_success(response_data, context_message, suggested_actions)
  end
  
  # Identify opportunities to save money
  # POST /api/v1/mcp/calculate_savings_potential
  def calculate_savings_potential
    timeframe = @sanitized_params[:parsed_timeframe] || TimeExpressionParser.parse('recent')
    focus_categories = @sanitized_params[:focus_categories] || %w[subscriptions dining entertainment]
    
    savings_opportunities = []
    
    focus_categories.each do |category|
      opportunities = find_savings_opportunities(category, timeframe)
      savings_opportunities.concat(opportunities) if opportunities.any?
    end
    
    # Sort by potential savings amount
    savings_opportunities.sort_by! { |opp| -opp[:potential_monthly_savings] }
    
    total_potential_savings = savings_opportunities.sum { |opp| opp[:potential_monthly_savings] }
    
    response_data = {
      timeframe: @sanitized_params[:timeframe] || 'recent',
      focus_categories: focus_categories,
      opportunities: savings_opportunities,
      total_potential_monthly_savings: total_potential_savings,
      annual_potential_savings: total_potential_savings * 12
    }
    
    context_message = build_savings_potential_context(savings_opportunities, total_potential_savings)
    suggested_actions = ['analyze_spending_pattern', 'get_financial_summary']
    
    render_success(response_data, context_message, suggested_actions)
  end

  private

  def calculate_savings_summary(timeframe)
    summary = {
      total_saved: 0,
      income: 0,
      net_worth_change: 0,
      savings_accounts: []
    }
    
    # Calculate from bank statements if available
    if defined?(BankStatement)
      # Get deposits (income)
      deposits = current_user.bank_statements
                            .where(created_at: timeframe, amount: 1..)
                            .where.not(description: ['Transfer', 'ATM', 'Check'])
                            .sum(:amount)
      summary[:income] = deposits
      
      # Get account balances for savings accounts
      savings_accounts = current_user.bank_statements
                                    .where(account_name: ['Savings', 'Money Market', 'CD'])
                                    .group(:account_name)
                                    .maximum(:balance)
      summary[:savings_accounts] = savings_accounts.map do |account, balance|
        { name: account, balance: balance }
      end
      
      summary[:total_saved] = savings_accounts.values.sum
    end
    
    summary
  end

  def calculate_spending_summary(timeframe)
    summary = {
      total_spent: 0,
      by_category: {},
      top_expenses: [],
      transaction_count: 0
    }
    
    if defined?(BankStatement)
      # Get all expenses (negative amounts)
      expense_scope = current_user.bank_statements.where(amount: ...0)
      expense_scope = expense_scope.where(created_at: timeframe) if timeframe
      
      expenses = expense_scope.order(amount: :asc)
      
      summary[:total_spent] = -expenses.sum(:amount)
      summary[:transaction_count] = expenses.count
      
      # Group by category
      summary[:by_category] = expenses.group(:category)
                                    .sum(:amount)
                                    .transform_values { |amount| -amount }
                                    .sort_by { |_, amount| -amount }
                                    .to_h
      
      # Top individual expenses
      summary[:top_expenses] = expenses.limit(10).map do |txn|
        {
          description: txn.description,
          amount: -txn.amount,
          date: txn.transaction_date,
          category: txn.category
        }
      end
    end
    
    # Include Amazon orders if available
    if defined?(AmazonOrder)
      amazon_scope = current_user.amazon_orders
      amazon_scope = amazon_scope.where(order_date: timeframe) if timeframe
      
      amazon_total = amazon_scope.sum(:item_total)
      summary[:amazon_orders] = {
        total_spent: amazon_total,
        order_count: amazon_scope.count
      }
      
      summary[:total_spent] += amazon_total
    end
    
    summary
  end

  def calculate_investment_summary(timeframe)
    summary = {
      total_value: 0,
      accounts: [],
      recent_activity: []
    }
    
    # Fidelity investments
    if defined?(FidelityInvestment)
      fidelity_accounts = current_user.fidelity_investments
                                     .group(:account_name)
                                     .sum(:current_value)
      
      summary[:total_value] += fidelity_accounts.values.sum
      summary[:accounts].concat(
        fidelity_accounts.map { |name, value| { name: name, value: value, type: 'fidelity' } }
      )
      
      if timeframe
        recent_activity = current_user.fidelity_investments
                                     .where(created_at: timeframe)
                                     .order(created_at: :desc)
                                     .limit(10)
                                     .map do |inv|
          {
            type: 'fidelity_activity',
            date: inv.created_at,
            description: inv.description,
            amount: inv.amount
          }
        end
        summary[:recent_activity].concat(recent_activity)
      end
    end
    
    # Principal investments
    if defined?(PrincipalInvestment)
      principal_accounts = current_user.principal_investments
                                      .group(:account_name)
                                      .sum(:current_value)
      
      summary[:total_value] += principal_accounts.values.sum
      summary[:accounts].concat(
        principal_accounts.map { |name, value| { name: name, value: value, type: 'principal' } }
      )
    end
    
    summary
  end

  def generate_financial_forecasts(summary_data)
    forecasts = {}
    
    if summary_data[:spending]
      monthly_spending = summary_data[:spending][:total_spent]
      forecasts[:projected_annual_spending] = monthly_spending * 12
    end
    
    if summary_data[:savings]
      current_savings = summary_data[:savings][:total_saved]
      monthly_income = summary_data[:savings][:income]
      monthly_spending = summary_data[:spending]&.dig(:total_spent) || 0
      
      if monthly_income > 0 && monthly_spending > 0
        monthly_net = monthly_income - monthly_spending
        forecasts[:projected_savings_growth] = {
          monthly_net: monthly_net,
          projected_annual_growth: monthly_net * 12,
          projected_balance_next_year: current_savings + (monthly_net * 12)
        }
      end
    end
    
    forecasts
  end

  def analyze_spending_for_period(category, timeframe)
    spending_data = {
      total: 0,
      transaction_count: 0,
      average_transaction: 0,
      transactions: []
    }
    
    if defined?(BankStatement)
      scope = current_user.bank_statements.where(amount: ...0)
      scope = scope.where(created_at: timeframe) if timeframe
      scope = scope.where(category: category) if category.present?
      
      transactions = scope.order(transaction_date: :desc)
      
      spending_data[:total] = -transactions.sum(:amount)
      spending_data[:transaction_count] = transactions.count
      spending_data[:average_transaction] = spending_data[:transaction_count] > 0 ? 
                                          spending_data[:total] / spending_data[:transaction_count] : 0
      
      spending_data[:transactions] = transactions.limit(20).map do |txn|
        {
          description: txn.description,
          amount: -txn.amount,
          date: txn.transaction_date,
          category: txn.category
        }
      end
    end
    
    spending_data
  end

  def parse_comparison_timeframe(compare_to)
    return nil if compare_to.blank?
    
    TimeExpressionParser.parse(compare_to)
  rescue ArgumentError
    nil
  end

  def generate_spending_insights(current, comparison, category)
    insights = []
    
    if comparison
      spending_change = current[:total] - comparison[:total]
      percentage_change = comparison[:total] > 0 ? 
                         ((spending_change / comparison[:total]) * 100).round(1) : 0
      
      if spending_change > 0
        insights << "Spending increased by $#{spending_change.round(2)} (#{percentage_change}%)"
      elsif spending_change < 0
        insights << "Spending decreased by $#{(-spending_change).round(2)} (#{percentage_change.abs}%)"
      else
        insights << "Spending remained roughly the same"
      end
    end
    
    if current[:transaction_count] > 0
      insights << "Average transaction: $#{current[:average_transaction].round(2)}"
      
      # Find unusual transactions
      high_transactions = current[:transactions].select { |t| t[:amount] > current[:average_transaction] * 2 }
      if high_transactions.any?
        insights << "#{high_transactions.length} transactions were significantly above average"
      end
    end
    
    insights
  end

  def find_savings_opportunities(category, timeframe)
    opportunities = []
    
    return opportunities unless defined?(BankStatement)
    
    # Analyze recurring charges
    recurring_charges = current_user.bank_statements
                                   .where(amount: ...0, created_at: timeframe)
                                   .where("description ILIKE ?", "%subscription%")
                                   .or(current_user.bank_statements
                                                  .where(amount: ...0, created_at: timeframe)
                                                  .where("description ILIKE ?", "%monthly%"))
                                   .group(:description)
                                   .average(:amount)
    
    recurring_charges.each do |description, avg_amount|
      # Suggest reviewing subscriptions over $10/month
      if -avg_amount > 10
        opportunities << {
          type: 'subscription_review',
          description: "Review #{description}",
          current_monthly_cost: -avg_amount,
          potential_monthly_savings: -avg_amount * 0.5, # Assume 50% potential savings
          confidence: 'medium'
        }
      end
    end
    
    # Analyze dining spending
    if category == 'dining'
      dining_spending = current_user.bank_statements
                                   .where(amount: ...0, created_at: timeframe)
                                   .where("category ILIKE ? OR description ILIKE ?", "%dining%", "%restaurant%")
                                   .sum(:amount)
      
      if -dining_spending > 300 # More than $300/month on dining
        opportunities << {
          type: 'dining_optimization',
          description: 'Reduce restaurant spending by cooking more meals at home',
          current_monthly_cost: -dining_spending,
          potential_monthly_savings: -dining_spending * 0.3, # 30% reduction
          confidence: 'high'
        }
      end
    end
    
    opportunities
  end

  def build_financial_summary_context(summary_data, timeframe)
    parts = []
    
    if summary_data[:spending]
      parts << "$#{summary_data[:spending][:total_spent].round(2)} spent"
    end
    
    if summary_data[:savings]
      parts << "$#{summary_data[:savings][:total_saved].round(2)} in savings"
    end
    
    if summary_data[:investments]
      parts << "$#{summary_data[:investments][:total_value].round(2)} in investments"
    end
    
    timeframe_desc = describe_timeframe(@sanitized_params[:timeframe], timeframe)
    "Financial summary for #{timeframe_desc}: #{parts.join(', ')}"
  end

  def build_spending_analysis_context(category, current, comparison)
    message = "Spending analysis"
    message += " for #{category}" if category.present?
    message += ": $#{current[:total].round(2)} across #{current[:transaction_count]} transactions"
    
    if comparison
      change = current[:total] - comparison[:total]
      if change > 0
        message += " (up $#{change.round(2)} from comparison period)"
      elsif change < 0
        message += " (down $#{(-change).round(2)} from comparison period)"
      end
    end
    
    message
  end

  def build_savings_potential_context(opportunities, total_potential)
    if opportunities.empty?
      "No significant savings opportunities identified"
    else
      "Found #{opportunities.length} savings opportunities with potential monthly savings of $#{total_potential.round(2)}"
    end
  end
end
