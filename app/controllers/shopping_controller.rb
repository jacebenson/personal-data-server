class ShoppingController < ApplicationController
  before_action :authenticate_user!

  def index
    @amazon_orders_count = current_user.amazon_orders.count
    @amazon_digital_orders_count = current_user.amazon_orders.where(order_type: 'digital').count
    @last_amazon_upload = current_user.amazon_orders.maximum(:created_at)
    @last_digital_upload = current_user.amazon_orders.where(order_type: 'digital').maximum(:created_at)
  end

  def upload
    # Amazon orders upload page
  end

  def upload_digital
    # Amazon digital orders upload page
  end

  def upload_orders
    # Handle Amazon orders file upload
    if params[:file].present?
      begin
        AmazonOrdersImportService.new(current_user, params[:file]).import
        redirect_to shopping_path, notice: 'Amazon orders uploaded successfully!'
      rescue StandardError => e
        redirect_to upload_shopping_index_path, alert: "Error uploading orders: #{e.message}"
      end
    else
      redirect_to upload_shopping_index_path, alert: 'Please select a file to upload.'
    end
  end

  def upload_digital_orders
    # Handle Amazon digital orders file upload
    if params[:file].present?
      begin
        AmazonDigitalImportService.new(current_user, params[:file]).import
        redirect_to shopping_path, notice: 'Amazon digital orders uploaded successfully!'
      rescue StandardError => e
        redirect_to upload_digital_shopping_index_path, alert: "Error uploading digital orders: #{e.message}"
      end
    else
      redirect_to upload_digital_shopping_index_path, alert: 'Please select a file to upload.'
    end
  end

  def view_orders
    # Show imported Amazon order records with pagination
    page = params[:page].to_i
    page = 1 if page < 1
    per_page = 50
    offset = (page - 1) * per_page

    # Get Amazon orders with filtering
    @amazon_orders = current_user.amazon_orders.order(order_date: :desc)
    
    if params[:search].present?
      @amazon_orders = @amazon_orders.where("product_name ILIKE ?", "%#{params[:search]}%")
    end
    
    if params[:order_type].present? && params[:order_type] != "all"
      @amazon_orders = @amazon_orders.where(order_type: params[:order_type])
    end

    @total_count = @amazon_orders.count
    @amazon_orders = @amazon_orders.limit(per_page).offset(offset)
    
    @page = page
    @per_page = per_page
    @total_pages = (@total_count.to_f / per_page).ceil
    
    # For filters
    @available_order_types = current_user.amazon_orders.distinct.pluck(:order_type).compact.sort
  end

  def clear_orders
    current_user.amazon_orders.destroy_all
    redirect_to shopping_path, notice: 'Amazon orders cleared successfully!'
  end
end
