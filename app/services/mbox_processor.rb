require "mail"
require "reverse_markdown"

class MboxProcessor
  def initialize(file, user)
    @file = file
    @user = user
    @imported_count = 0
    @skipped_count = 0
    @duplicate_count = 0
    @errors = []
    @chunk_size = 10.megabytes # Process 10MB chunks at a time
  end

  def process
    Rails.logger.info "Starting MBOX processing for user #{@user.id}"
    file_size_mb = File.size(@file.path) / 1.megabyte
    Rails.logger.info "Processing file: #{@file.original_filename} (#{file_size_mb}MB)"

    begin
      # Determine the folder name from the filename
      folder_name = extract_folder_name(@file.original_filename)

      # Process the file in streaming chunks to handle large files
      process_file_in_chunks(folder_name)

      Rails.logger.info "✅ MBOX processing completed for #{@file.original_filename}"
      Rails.logger.info "📊 Final stats: #{@imported_count} imported, #{@skipped_count} skipped, #{@errors.length} errors"

      {
        count: @imported_count,
        skipped: @skipped_count,
        duplicates: @duplicate_count,
        errors: @errors
      }

    rescue => e
      Rails.logger.error "❌ Error processing MBOX file: #{e.message}"
      @errors << e.message
      raise e
    end
  end

  private

  def process_file_in_chunks(folder_name)
    buffer = ""
    message_count = 0
    file_size = File.size(@file.path)
    bytes_processed = 0

    File.open(@file.path, "rb") do |file|
      while chunk = file.read(@chunk_size)
        bytes_processed += chunk.bytesize

        # Ensure chunk is UTF-8 encoded
        chunk = ensure_utf8_encoding(chunk)
        buffer += chunk

        # Process complete messages from buffer
        while buffer.include?("\nFrom ")
          # Find the next message boundary
          from_index = buffer.index("\nFrom ")

          if from_index
            # Extract one complete message
            message_content = buffer[0...from_index]
            buffer = "From " + buffer[from_index + 6..-1] # Keep "From " for next message

            unless message_content.strip.empty?
              process_message(message_content, folder_name, message_count)
              message_count += 1

              # Show progress every 250 messages with file progress
              if message_count % 250 == 0
                progress_percent = (bytes_processed.to_f / file_size * 100).round(1)
                print "\r📧 Processing #{File.basename(@file.original_filename)}: #{message_count} messages processed (#{progress_percent}% of file)"
                $stdout.flush

                # Force garbage collection to free memory
                GC.start if message_count % 1000 == 0
              end
            end
          else
            break # No more complete messages in buffer
          end
        end
      end

      # Process any remaining content in buffer as the last message
      unless buffer.strip.empty?
        process_message(buffer, folder_name, message_count)
        message_count += 1
      end

      # Clear the progress line and show completion
      print "\r" + " " * 80 + "\r"
      Rails.logger.info "📧 Processed #{message_count} total messages from #{File.basename(@file.original_filename)}"
    end
  end

  def ensure_utf8_encoding(content)
    return content if content.nil? || content.empty?

    # If already UTF-8 and valid, return as-is
    if content.encoding == Encoding::UTF_8 && content.valid_encoding?
      return content
    end

    # Try to convert to UTF-8
    begin
      # Force binary encoding first, then convert to UTF-8
      content.force_encoding("BINARY")
      content.encode("UTF-8", "BINARY", invalid: :replace, undef: :replace, replace: "?")
    rescue Encoding::UndefinedConversionError, Encoding::InvalidByteSequenceError
      # If that fails, try common encodings
      [ "ISO-8859-1", "Windows-1252" ].each do |encoding|
        begin
          return content.force_encoding(encoding).encode("UTF-8", invalid: :replace, undef: :replace, replace: "?")
        rescue
          next
        end
      end

      # Last resort: force UTF-8 and replace invalid characters
      content.force_encoding("UTF-8")
      content.scrub("?")
    end
  end

  def process_message(raw_message, folder_name, index)
    begin
      # Skip empty messages
      return if raw_message.strip.empty?

      # Ensure the message content is properly encoded
      raw_message = ensure_utf8_encoding(raw_message)

      # Parse the message with the Mail gem
      message = Mail.new(raw_message)

      # Extract message details
      message_id = extract_message_id(message, index)
      subject = extract_subject(message)
      sender_email, sender_name = extract_sender(message)
      recipient_emails = extract_recipients(message)
      received_date = extract_date(message)
      content, content_type = extract_content(message)
      message_size = raw_message.bytesize

      # Check for existing message to prevent duplicates
      existing_message = @user.email_messages.find_by(message_id: message_id)

      if existing_message
        @duplicate_count += 1
        @skipped_count += 1
        return
      end

      # Create new email message record
      @user.email_messages.create!(
        message_id: message_id,
        subject: subject,
        sender_email: sender_email,
        sender_name: sender_name,
        recipient_emails: recipient_emails,
        received_date: received_date,
        content: content,
        content_type: content_type,
        folder: folder_name,
        message_size: message_size,
        attachments_count: extract_attachment_info(message).length
      )

      @imported_count += 1

    rescue => e
      Rails.logger.warn "Failed to process message #{index + 1}: #{e.message}" if @errors.length < 10
      @errors << "Message #{index + 1} processing error: #{e.message}"
      @skipped_count += 1
    end
  end

  def extract_folder_name(filename)
    # Extract folder name from filename, removing .mbox extension
    File.basename(filename, ".mbox").humanize
  end

  def extract_message_id(message, index)
    # Try to get Message-ID header
    message_id = message.message_id
    return message_id.to_s.gsub(/[<>]/, "") if message_id.present?

    # Generate a unique ID based on date, subject, and sender
    date_str = message.date&.to_s || Time.current.to_s
    subject_str = message.subject || "no-subject"
    from_str = message.from&.first || "unknown-sender"

    Digest::MD5.hexdigest("#{date_str}-#{subject_str}-#{from_str}-#{index}")
  end

  def extract_subject(message)
    subject = message.subject
    return subject.to_s.strip if subject.present?
    "(No Subject)"
  end

  def extract_sender(message)
    from_address = message.from&.first
    Rails.logger.debug "Raw from_address: #{from_address.inspect}"
    return [ nil, nil ] unless from_address

    # The from_address is already a string, not an address object
    sender_email = from_address.to_s
    sender_name = nil

    Rails.logger.debug "Sender email before parsing: #{sender_email}"

    # Parse "Name <email@domain.com>" or just "email@domain.com" format
    if sender_email.match(/^(.+)\s*<(.+@.+)>$/)
      # Format: "Name <email@domain.com>"
      sender_name = $1.strip.gsub(/["']/, "")
      sender_email = $2.strip
    elsif sender_email.match(/^(.+@.+)$/)
      # Format: just "email@domain.com"
      sender_email = sender_email.strip
      sender_name = nil
    end

    Rails.logger.debug "Final sender_email: #{sender_email}, sender_name: #{sender_name}"
    [ sender_email, sender_name ]
  end

  def extract_recipients(message)
    recipients = []

    # Collect To, Cc, and Bcc recipients
    [ message.to, message.cc, message.bcc ].each do |recipient_list|
      next unless recipient_list
      Rails.logger.debug "Recipients list: #{recipient_list.inspect}"
      recipients.concat(recipient_list)
    end

    result = recipients.compact.uniq.join(", ")
    Rails.logger.debug "Final recipients: #{result}"
    result
  end

  def extract_date(message)
    return message.date if message.date.present?

    # Fallback to delivery date or current time
    if message.header["Delivery-Date"]
      begin
        Time.parse(message.header["Delivery-Date"].to_s)
      rescue
        Time.current
      end
    else
      Time.current
    end
  end

  def extract_content(message)
    content = ""
    content_type = "text/markdown"

    # Collect attachment information
    attachment_info = extract_attachment_info(message)

    if message.multipart?
      # Handle multipart messages - prefer HTML over text for better conversion
      html_part = find_main_html_part(message)
      text_part = find_main_text_part(message)

      if html_part
        raw_content = decode_content(html_part)
        Rails.logger.debug "Processing HTML part: #{raw_content.length} chars"
        content = convert_html_to_markdown(raw_content)
      elsif text_part
        raw_content = decode_content(text_part)
        Rails.logger.debug "Processing text part: #{raw_content.length} chars"
        content = convert_text_to_markdown(raw_content)
      else
        # Fallback to message body, but try to extract meaningful content
        raw_content = decode_content(message)
        Rails.logger.debug "Processing fallback body: #{raw_content.length} chars"
        if looks_like_html(raw_content)
          content = convert_html_to_markdown(raw_content)
        else
          content = convert_text_to_markdown(raw_content)
        end
      end
    else
      # Single part message
      raw_content = decode_content(message)
      Rails.logger.debug "Processing single part: #{raw_content.length} chars, content_type: #{message.content_type}"

      if message.content_type&.include?("html") || looks_like_html(raw_content)
        content = convert_html_to_markdown(raw_content)
      else
        content = convert_text_to_markdown(raw_content)
      end
    end

    # Log content before cleaning
    content_before_cleaning = content.dup
    content_before_length = content.length

    # Post-process content to remove obvious non-email content
    cleaned_content = clean_extracted_content(content)

    # If cleaning removed too much content, use the original
    if cleaned_content.length < content_before_length * 0.1 && content_before_length > 100
      Rails.logger.warn "Content cleaning too aggressive (#{content_before_length} -> #{cleaned_content.length}), using original"
      content = content_before_cleaning
    else
      content = cleaned_content
    end

    # Add attachment information to content
    if attachment_info.any?
      content += "\n\n---\n\n**Attachments:**\n"
      attachment_info.each do |attachment|
        content += "- #{attachment[:filename]} (#{attachment[:content_type]})\n"
      end
    end

    # Limit content size to prevent database issues
    content = content[0, 50000] if content.length > 50000

    [ content, content_type ]
  end

  def find_main_html_part(message)
    # Look for the main HTML part, avoiding calendar invites, images, etc.
    html_parts = message.all_parts.select do |part|
      part.content_type&.include?("text/html") &&
      !part.content_type&.include?("calendar") &&
      !part.attachment?
    end

    # Return the largest HTML part (likely the main content)
    html_parts.max_by { |part| part.body.decoded.length }
  end

  def find_main_text_part(message)
    # Look for the main text part
    text_parts = message.all_parts.select do |part|
      part.content_type&.include?("text/plain") &&
      !part.content_type&.include?("calendar") &&
      !part.attachment?
    end

    # Return the largest text part (likely the main content)
    text_parts.max_by { |part| part.body.decoded.length }
  end

  def looks_like_html(content)
    # Check if content appears to be HTML
    content.to_s.strip.match?(/^\s*<!DOCTYPE|^\s*<html|<\/html>|<body|<div|<p\s/i)
  end

  def clean_extracted_content(content)
    return "" if content.blank?

    lines = content.split("\n")
    original_line_count = lines.length

    # Remove lines that look like CSS, JavaScript, or other non-content
    cleaned_lines = lines.reject do |line|
      stripped = line.strip

      # Skip empty lines but keep lines with some content
      next true if stripped.length == 0

      # Be more conservative - only skip obvious technical content
      next true if stripped.match?(/^[\w\-\.#:@]+\s*\{\s*$/)  # CSS selectors with opening brace
      next true if stripped.match?(/^\s*[\w\-]+\s*:\s*[^;]*;\s*$/)  # Complete CSS properties with semicolon
      next true if stripped.match?(/^\s*\}\s*$/)  # Closing braces only
      next true if stripped.match?(/^@media\s+/)  # Media queries
      next true if stripped.match?(/^@import\s+/)  # Import statements
      next true if stripped.match?(/^@font-face\s*\{/)  # Font face declarations

      # Skip obvious JavaScript
      next true if stripped.match?(/^(var|let|const|function|if|for|while)\s+\w/)
      next true if stripped.match?(/^\s*\{?\s*["']@type["']/)  # JSON-LD type declarations

      # Skip lines that are mostly CSS class selectors (lots of dots and hashes)
      css_selectors = stripped.scan(/[#\.]\w+/).length
      next true if css_selectors > 8  # Increased threshold

      # Skip lines with multiple hex colors (likely CSS)
      hex_colors = stripped.scan(/#[0-9a-fA-F]{3,6}/).length
      next true if hex_colors > 3  # Increased threshold

      # Skip lines that are mostly punctuation but be less aggressive
      alphanumeric_chars = stripped.gsub(/[^a-zA-Z0-9\s]/, "").length
      total_chars = stripped.length
      next true if total_chars > 20 && alphanumeric_chars.to_f / total_chars < 0.3

      false
    end

    result = cleaned_lines.join("\n").strip
    removed_lines = original_line_count - cleaned_lines.length

    # Log if we removed a lot of content to help debug
    if removed_lines > original_line_count * 0.5 && original_line_count > 10
      Rails.logger.warn "Removed #{removed_lines}/#{original_line_count} lines from email content - may be too aggressive"
    end

    # Clean up excessive whitespace
    result = result.gsub(/\n{3,}/, "\n\n")
    result = result.gsub(/[ \t]+/, " ")

    result
  end

  def decode_content(mail_part)
    content = mail_part.body.decoded

    # Handle encoding issues
    if content.respond_to?(:force_encoding)
      content = content.force_encoding("UTF-8")
      unless content.valid_encoding?
        content = content.encode("UTF-8", invalid: :replace, undef: :replace, replace: "?")
      end
    end

    content
  end

  def convert_html_to_markdown(html_content)
    return "" if html_content.blank?

    begin
      # Clean up HTML before conversion
      cleaned_html = clean_html_content(html_content)

      # Configure ReverseMarkdown for better output
      ReverseMarkdown.configure do |config|
        config.remove_id_attributes = true
        config.remove_class_attributes = true
        config.remove_style_attributes = true
        config.whitespace_removal = :remove
        config.unknown_tags = :bypass
      end

      ReverseMarkdown.convert(cleaned_html)
    rescue => e
      Rails.logger.warn "Failed to convert HTML to markdown: #{e.message}"
      # Fallback to plain text extraction
      clean_html_fallback(html_content)
    end
  end

  def clean_html_content(html_content)
    # Remove script tags and their content
    cleaned = html_content.gsub(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/mi, "")

    # Remove style tags and their content
    cleaned = cleaned.gsub(/<style\b[^<]*(?:(?!<\/style>)<[^<]*)*<\/style>/mi, "")

    # Remove link tags (CSS references)
    cleaned = cleaned.gsub(/<link\b[^>]*>/i, "")

    # Remove meta tags
    cleaned = cleaned.gsub(/<meta\b[^>]*>/i, "")

    # Remove head section entirely if present
    cleaned = cleaned.gsub(/<head\b[^<]*(?:(?!<\/head>)<[^<]*)*<\/head>/mi, "")

    # Remove JSON-LD structured data
    cleaned = cleaned.gsub(/<script[^>]*type=["']application\/ld\+json["'][^>]*>.*?<\/script>/mi, "")

    # Remove HTML/DOCTYPE declarations
    cleaned = cleaned.gsub(/<!DOCTYPE[^>]*>/i, "")
    cleaned = cleaned.gsub(/<html[^>]*>/i, "")
    cleaned = cleaned.gsub(/<\/html>/i, "")

    # Remove body tags but keep content
    cleaned = cleaned.gsub(/<\/?body[^>]*>/i, "")

    # Clean up excessive whitespace
    cleaned = cleaned.gsub(/\s+/, " ").strip

    cleaned
  end

  def clean_html_fallback(html_content)
    # Aggressive plain text extraction as fallback
    text = html_content.dup

    # Remove script and style content
    text = text.gsub(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/mi, " ")
    text = text.gsub(/<style\b[^<]*(?:(?!<\/style>)<[^<]*)*<\/style>/mi, " ")

    # Remove all HTML tags
    text = text.gsub(/<[^>]*>/, " ")

    # Clean up whitespace
    text = text.gsub(/\s+/, " ").strip

    # Only remove obvious CSS content, be more conservative
    text_lines = text.split("\n")
    cleaned_lines = text_lines.reject do |line|
      stripped = line.strip
      stripped.match?(/^[\w\-\.#:]+\s*\{\s*$/) ||  # CSS selectors with opening brace only
      stripped.match?(/^\s*\}\s*$/) ||             # Closing braces only
      stripped.match?(/^@media\s+/) ||             # Media queries
      stripped.match?(/^@import\s+/) ||            # Import statements
      stripped.length < 5                          # Very short lines only
    end

    cleaned_lines.join("\n").strip
  end

  def convert_text_to_markdown(text_content)
    return "" if text_content.blank?

    # For plain text, we'll preserve formatting and make minimal markdown adjustments
    text_content.strip
  end

  def extract_attachment_info(message)
    attachments = []

    return attachments unless message.attachments

    message.attachments.each do |attachment|
      begin
        filename = attachment.filename || "unknown_attachment"
        content_type = attachment.content_type || "application/octet-stream"

        attachments << {
          filename: filename,
          content_type: content_type
        }
      rescue => e
        Rails.logger.warn "Failed to extract attachment info: #{e.message}"
        attachments << {
          filename: "unknown_attachment",
          content_type: "application/octet-stream"
        }
      end
    end

    attachments
  end
end
