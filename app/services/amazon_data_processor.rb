require "csv"

class AmazonDataProcessor
  def initialize(file_path, user, file_type)
    @file_path = file_path
    @user = user
    @file_type = file_type.to_s.downcase # 'digital' or 'retail'
  end

  def process
    case @file_type
    when "digital"
      process_digital_orders
    when "retail"
      process_retail_orders
    else
      raise ArgumentError, "Invalid file type: #{@file_type}. Must be 'digital' or 'retail'"
    end
  end

  private

  def process_digital_orders
    result = { count: 0, skipped: 0, duplicates: 0 }

    CSV.foreach(@file_path, headers: true, header_converters: :symbol) do |row|
      begin
        # Parse the digital order data
        order_data = {
          user: @user,
          order_type: "digital",
          order_id: row[:orderid],
          order_date: parse_date(row[:orderdate]),
          asin: row[:asin],
          product_name: row[:productname],
          digital_order_item_id: row[:digitalorderitemid],
          our_price: parse_decimal(row[:ourprice]),
          our_price_currency_code: row[:ourpricecurrencycode],
          list_price_amount: parse_decimal(row[:listpriceamount]),
          list_price_currency_code: row[:listpricecurrencycode],
          is_fulfilled: parse_boolean(row[:isfulfilled]),
          fulfilled_date: parse_date(row[:fulfilleddate]),
          marketplace: row[:marketplace],
          website: row[:marketplace], # Use marketplace as website since that's where the service info is stored
          publisher: row[:sellerofrecord], # Use SellerOfRecord as it contains the actual publisher info like "Audible"
          ship_from: row[:shipfrom],
          ship_to: row[:shipto],
          is_prime_eligible: parse_boolean(row[:isordereligibleforprimebenefit]),
          quantity: parse_integer(row[:originalquantity]),
          currency_code: row[:basecurrencycode],
          subscription_info: row[:subscriptionorderinfolist] # Captures subscription IDs for subscription orders
        }

        # Try to create the order - use digital_order_item_id for uniqueness since multiple items can have same order_id
        order = AmazonOrder.find_or_initialize_by(
          user: @user,
          digital_order_item_id: order_data[:digital_order_item_id],
          order_type: "digital"
        )

        if order.persisted?
          # Update existing order with new subscription info if it's missing
          if order.subscription_info.blank? && order_data[:subscription_info].present?
            order.update(subscription_info: order_data[:subscription_info])
          end
          result[:duplicates] += 1
          result[:skipped] += 1
        else
          order.assign_attributes(order_data)
          if order.save
            result[:count] += 1
          else
            Rails.logger.error "Failed to save digital Amazon order: #{order.errors.full_messages}"
            Rails.logger.error "Order data: #{order_data}"
            puts "Failed to save order: #{order.errors.full_messages}"
            result[:skipped] += 1
          end
        end

      rescue => e
        Rails.logger.error "Error processing digital Amazon order row: #{e.message}"
        Rails.logger.error "Row data: #{row.to_h}"
        puts "Error processing row: #{e.message}"
        result[:skipped] += 1
      end
    end

    result
  end

  def process_retail_orders
    result = { count: 0, skipped: 0, duplicates: 0 }

    CSV.foreach(@file_path, headers: true) do |row|
      begin
        # Parse the retail order data
        order_data = {
          user: @user,
          order_type: "retail",
          order_id: row["Order ID"],
          order_date: parse_date(row["Order Date"]),
          asin: row["ASIN"],
          product_name: row["Product Name"],
          unit_price: parse_decimal(row["Unit Price"]),
          unit_price_tax: parse_decimal(row["Unit Price Tax"]),
          shipping_charge: parse_decimal(row["Shipping Charge"]),
          total_discounts: parse_decimal(row["Total Discounts"]),
          total_owed: parse_decimal(row["Total Owed"]),
          product_condition: row["Product Condition"],
          quantity: parse_integer(row["Quantity"]),
          payment_instrument_type: row["Payment Instrument Type"],
          order_status: row["Order Status"],
          shipment_status: row["Shipment Status"],
          ship_date: parse_date(row["Ship Date"]),
          shipping_option: row["Shipping Option"],
          shipping_address: row["Shipping Address"],
          billing_address: row["Billing Address"],
          tracking_number: row["Carrier Name & Tracking Number"],
          gift_message: row["Gift Message"],
          currency_code: row["Currency"]
        }

        # Try to create the order (using ASIN as additional uniqueness for retail since same order can have multiple items)
        order = AmazonOrder.find_or_initialize_by(
          user: @user,
          order_id: order_data[:order_id],
          asin: order_data[:asin],
          order_type: "retail"
        )

        if order.persisted?
          result[:duplicates] += 1
          result[:skipped] += 1
        else
          order.assign_attributes(order_data)
          if order.save
            result[:count] += 1
          else
            Rails.logger.error "Failed to save retail Amazon order: #{order.errors.full_messages}"
            result[:skipped] += 1
          end
        end

      rescue => e
        Rails.logger.error "Error processing retail Amazon order row: #{e.message}"
        result[:skipped] += 1
      end
    end

    result
  end

  def parse_date(date_string)
    return nil if date_string.blank? || date_string == "Not Applicable"

    # Handle different date formats
    if date_string.include?("T")
      DateTime.parse(date_string)
    else
      Date.parse(date_string)
    end
  rescue
    nil
  end

  def parse_decimal(value)
    return nil if value.blank? || value == "Not Applicable"
    value.to_f
  end

  def parse_integer(value)
    return nil if value.blank? || value == "Not Applicable"
    value.to_i
  end

  def parse_boolean(value)
    return false if value.blank? || value == "Not Applicable"
    value.to_s.downcase == "yes" || value.to_s.downcase == "true"
  end
end
