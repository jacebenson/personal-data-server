class EmailMessage < ApplicationRecord
  belongs_to :user

  validates :message_id, presence: true
  validates :message_id, uniqueness: { scope: :user_id, message: "Email message already exists" }
  validates :received_date, presence: true
  validates :message_size, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :attachments_count, presence: true, numericality: { greater_than_or_equal_to: 0 }
  
  scope :recent, -> { order(received_date: :desc) }
  scope :by_folder, ->(folder) { where(folder: folder) }
  scope :by_sender, ->(email) { where(sender_email: email) }
  scope :by_date_range, ->(start_date, end_date) { where(received_date: start_date..end_date) }
  scope :with_attachments, -> { where('attachments_count > 0') }
  
  # Search methods
  scope :search_subject, ->(term) { where("subject LIKE ?", "%#{term}%") }
  scope :search_content, ->(term) { where("content LIKE ?", "%#{term}%") }
  scope :search_sender, ->(term) { where("sender_email LIKE ? OR sender_name LIKE ?", "%#{term}%", "%#{term}%") }
  
  def formatted_size
    return "0 B" if message_size.zero?
    
    units = ['B', 'KB', 'MB', 'GB']
    size = message_size.to_f
    unit_index = 0
    
    while size >= 1024 && unit_index < units.length - 1
      size /= 1024
      unit_index += 1
    end
    
    "#{size.round(1)} #{units[unit_index]}"
  end
  
  def short_subject(length = 50)
    return "(No Subject)" if subject.blank?
    subject.length > length ? "#{subject[0..length-1]}..." : subject
  end
  
  def sender_display_name
    return sender_name if sender_name.present?
    return sender_email if sender_email.present?
    "Unknown Sender"
  end
  
  def content_preview(length = 200)
    return "" if content.blank?
    
    # Strip HTML tags if content_type indicates HTML
    preview_text = if content_type&.include?('html')
                     content.gsub(/<[^>]*>/, ' ').gsub(/\s+/, ' ')
                   else
                     content
                   end
    
    preview_text = preview_text.strip
    preview_text.length > length ? "#{preview_text[0..length-1]}..." : preview_text
  end
  
  def recipient_list
    return [] if recipient_emails.blank?
    recipient_emails.split(',').map(&:strip)
  end
  
  # Class methods for statistics
  def self.total_size_for_user(user_id)
    where(user_id: user_id).sum(:message_size)
  end
  
  def self.folder_stats_for_user(user_id)
    where(user_id: user_id)
      .group(:folder)
      .group("CASE WHEN attachments_count > 0 THEN 'with_attachments' ELSE 'without_attachments' END")
      .count
  end
  
  def self.sender_stats_for_user(user_id, limit = 10)
    where(user_id: user_id)
      .group(:sender_email)
      .order('COUNT(*) DESC')
      .limit(limit)
      .count
  end
end
