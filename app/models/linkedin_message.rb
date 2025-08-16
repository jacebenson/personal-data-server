class LinkedinMessage < ApplicationRecord
  belongs_to :user

  validates :conversation_id, presence: true
  validates :from_name, presence: true
  validates :sent_at, presence: true

  scope :recent, -> { order(sent_at: :desc) }
  scope :by_conversation, ->(conversation_id) { where(conversation_id: conversation_id) }
  scope :by_folder, ->(folder) { where(folder: folder) }
  scope :by_sender, ->(name) { where(from_name: name) }
  scope :by_date_range, ->(start_date, end_date) { where(sent_at: start_date..end_date) }
  scope :drafts, -> { where(is_draft: true) }
  scope :sent_messages, -> { where(is_draft: false) }

  # Search methods
  scope :search_content, ->(term) { where("content LIKE ? COLLATE NOCASE", "%#{term}%") }
  scope :search_subject, ->(term) { where("subject LIKE ? COLLATE NOCASE", "%#{term}%") }
  scope :search_participant, ->(term) { where("from_name LIKE ? COLLATE NOCASE OR to_name LIKE ? COLLATE NOCASE", "%#{term}%", "%#{term}%") }

  def conversation_participants
    # Get all unique participants in this conversation
    user.linkedin_messages
        .where(conversation_id: conversation_id)
        .pluck(:from_name, :to_name)
        .flatten
        .uniq
        .compact
  end

  def conversation_messages_count
    user.linkedin_messages.where(conversation_id: conversation_id).count
  end

  def sender_display_name
    from_name.present? ? from_name : "Unknown Sender"
  end

  def recipient_display_name
    to_name.present? ? to_name : "Unknown Recipient"
  end

  def content_preview(length = 200)
    return "" if content.blank?

    # Clean up the content and truncate
    clean_content = content.strip
    clean_content.length > length ? "#{clean_content[0..length-1]}..." : clean_content
  end

  def has_attachments?
    attachments.present? && attachments != ""
  end

  def attachment_list
    return [] unless has_attachments?

    # Split attachments by comma or newline
    attachments.split(/[,\n]/).map(&:strip).reject(&:blank?)
  end

  def formatted_date
    sent_at.strftime("%B %d, %Y at %I:%M %p")
  end

  def conversation_url
    "https://www.linkedin.com/messaging/thread/#{conversation_id}" if conversation_id.present?
  end

  def same_day_as?(other_message)
    sent_at.to_date == other_message.sent_at.to_date
  end

  # Check if this is likely a duplicate message
  def potential_duplicate?
    user.linkedin_messages
        .where(conversation_id: conversation_id)
        .where(from_name: from_name)
        .where(sent_at: sent_at)
        .where(content: content)
        .where.not(id: id)
        .exists?
  end

  # Group messages by conversation for display
  def self.grouped_by_conversation
    includes(:user)
      .group_by(&:conversation_id)
      .transform_values { |messages| messages.sort_by(&:sent_at) }
  end

  # Get conversation statistics
  def self.conversation_stats(conversation_id)
    messages = where(conversation_id: conversation_id)
    {
      total_messages: messages.count,
      participants: messages.pluck(:from_name, :to_name).flatten.uniq.compact,
      date_range: {
        first: messages.minimum(:sent_at),
        last: messages.maximum(:sent_at)
      },
      drafts_count: messages.where(is_draft: true).count
    }
  end
end
