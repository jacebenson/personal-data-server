require "mail"
# require "reverse_markdown"

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

  def read_file_with_encoding(file_path)
    # Always read as binary first to avoid encoding issues
    content = File.read(file_path, encoding: "BINARY")

    # Try different encodings in order of preference
    encodings_to_try = [ "UTF-8", "ISO-8859-1", "Windows-1252", "ASCII-8BIT" ]

    encodings_to_try.each do |encoding|
      begin
        # Try to force the encoding and validate
        test_content = content.dup.force_encoding(encoding)

        if encoding == "UTF-8"
          # For UTF-8, we need valid encoding
          next unless test_content.valid_encoding?
          return test_content
        else
          # For other encodings, convert to UTF-8
          converted = test_content.encode("UTF-8", invalid: :replace, undef: :replace, replace: "?")
          return converted if converted.valid_encoding?
        end
      rescue Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError
        next
      end
    end

    # If all else fails, force UTF-8 with aggressive replacement
    content.force_encoding("UTF-8")
    content.encode("UTF-8", invalid: :replace, undef: :replace, replace: "?")
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
      attachments_count = count_attachments(message)

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
        attachments_count: attachments_count
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
    return [ nil, nil ] unless from_address

    # The from_address is already a string, not an address object
    sender_email = from_address.to_s
    sender_name = nil

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

    [ sender_email, sender_name ]
  end

  def extract_recipients(message)
    recipients = []

    # Collect To, Cc, and Bcc recipients
    [ message.to, message.cc, message.bcc ].each do |recipient_list|
      next unless recipient_list
      recipients.concat(recipient_list)
    end

    recipients.compact.uniq.join(", ")
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
    # TODO Convert to markdown
    content_type = "text/plain"
    content = ""

    if message.multipart?
      # Handle multipart messages
      text_part = message.text_part
      html_part = message.html_part

      if html_part
        content = html_part.decoded
        content_type = "text/html"
      elsif text_part
        content = text_part.decoded
        content_type = "text/plain"
      else
        content = message.body.decoded
      end
    else
      # Single part message
      content = message.body.decoded
      if message.content_type&.include?("html")
        content_type = "text/html"
      end
    end

    # Handle encoding issues
    if content.respond_to?(:force_encoding)
      content = content.force_encoding("UTF-8")
      unless content.valid_encoding?
        content = content.encode("UTF-8", invalid: :replace, undef: :replace, replace: "?")
      end
    end
    # content = reverse_markdown.convert(content)

    # Limit content size to prevent database issues
    content = content[0, 50000] if content.length > 50000

    [ content, content_type ]
  end

  def count_attachments(message)
    return 0 unless message.attachments
    message.attachments.length
  end
end
