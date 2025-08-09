require "zip"

class VcardProcessor
  attr_reader :user, :errors, :warnings

  def initialize(uploaded_file, user, source_file_name = nil)
    @uploaded_file = uploaded_file
    @user = user
    @source_file_name = source_file_name || uploaded_file.original_filename
    @errors = []
    @warnings = []
    @imported_count = 0
    @skipped_count = 0
    @duplicate_count = 0
  end

  def process
    begin
      if zip_file?
        process_zip_file
      else
        process_vcard_content(read_file_content, @source_file_name)
      end

      {
        count: @imported_count,
        skipped: @skipped_count,
        duplicates: @duplicate_count,
        errors: @errors,
        warnings: @warnings
      }
    rescue => e
      @errors << "Failed to process file: #{e.message}"
      Rails.logger.error "VcardProcessor error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      {
        count: 0,
        skipped: 0,
        duplicates: 0,
        errors: @errors,
        warnings: @warnings
      }
    end
  end

  private

  def zip_file?
    @source_file_name.downcase.end_with?(".zip") ||
    (@uploaded_file.respond_to?(:content_type) && @uploaded_file.content_type == "application/zip")
  end

  def read_file_content
    if @uploaded_file.respond_to?(:read)
      @uploaded_file.read
    elsif @uploaded_file.respond_to?(:path)
      File.read(@uploaded_file.path)
    else
      @uploaded_file.to_s
    end
  end

  def process_zip_file
    content = read_file_content

    Zip::InputStream.open(StringIO.new(content)) do |io|
      while (entry = io.get_next_entry)
        next if entry.directory?
        next unless vcard_file?(entry.name)

        begin
          vcard_content = io.read
          process_vcard_content(vcard_content, entry.name)
        rescue => e
          @errors << "Error processing #{entry.name}: #{e.message}"
          Rails.logger.error "Error processing vCard file #{entry.name}: #{e.message}"
        end
      end
    end
  rescue => e
    @errors << "Error reading ZIP file: #{e.message}"
    Rails.logger.error "Error reading ZIP file: #{e.message}"
  end

  def vcard_file?(filename)
    filename.downcase.end_with?(".vcf", ".vcard") ||
    filename.downcase.include?("contact")
  end

  def process_vcard_content(content, filename)
    return if content.blank?

    # Handle different encodings
    content = normalize_encoding(content)

    # Split multiple vCards in a single file
    vcards = split_vcards(content)

    vcards.each_with_index do |vcard_text, index|
      begin
        process_single_vcard(vcard_text, filename, index + 1)
      rescue => e
        @errors << "Error processing vCard #{index + 1} in #{filename}: #{e.message}"
        Rails.logger.error "Error processing vCard: #{e.message}"
      end
    end
  end

  def normalize_encoding(content)
    # Try to detect and convert encoding
    if content.encoding != Encoding::UTF_8
      content = content.force_encoding("UTF-8")
    end

    # If invalid UTF-8, try common encodings
    unless content.valid_encoding?
      [ "ISO-8859-1", "Windows-1252" ].each do |encoding|
        begin
          return content.force_encoding(encoding).encode("UTF-8")
        rescue Encoding::UndefinedConversionError
          next
        end
      end
    end

    content
  end

  def split_vcards(content)
    # Split on BEGIN:VCARD, keeping the delimiter
    parts = content.split(/(?=BEGIN:VCARD)/i)
    parts.reject(&:blank?)
  end

  def process_single_vcard(vcard_text, filename, vcard_index)
    return if vcard_text.strip.empty?

    # Parse vCard properties
    properties = parse_vcard_properties(vcard_text)

    # Extract contact data
    contact_data = extract_contact_data(properties, filename)

    return if contact_data[:uid].blank?

    # Check for existing contact
    existing_contact = @user.contacts.find_by(uid: contact_data[:uid])

    if existing_contact
      @duplicate_count += 1
      @warnings << "Duplicate contact found: #{contact_data[:display_name] || contact_data[:uid]}"
      return
    end

    # Create new contact
    contact = @user.contacts.build(contact_data)

    if contact.save
      @imported_count += 1
    else
      @skipped_count += 1
      @errors << "Failed to save contact #{contact_data[:display_name] || contact_data[:uid]}: #{contact.errors.full_messages.join(', ')}"
    end
  end

  def parse_vcard_properties(vcard_text)
    properties = {}
    current_property = nil

    vcard_text.lines.each do |line|
      line = line.strip
      next if line.empty?

      # Handle line continuation
      if line.start_with?(" ", "\t") && current_property
        properties[current_property[:name]] ||= []
        properties[current_property[:name]].last[:value] += line.strip
        next
      end

      # Parse property line
      if line.include?(":")
        name_part, value_part = line.split(":", 2)

        # Parse property name and parameters
        if name_part.include?(";")
          property_name, *params = name_part.split(";")
          parameters = parse_parameters(params)
        else
          property_name = name_part
          parameters = {}
        end

        property_name = property_name.upcase
        current_property = { name: property_name, parameters: parameters }

        properties[property_name] ||= []
        properties[property_name] << {
          value: value_part || "",
          parameters: parameters
        }
      end
    end

    properties
  end

  def parse_parameters(params)
    parameters = {}
    params.each do |param|
      if param.include?("=")
        key, value = param.split("=", 2)
        parameters[key.upcase] = value
      else
        parameters[param.upcase] = true
      end
    end
    parameters
  end

  def extract_contact_data(properties, filename)
    data = {
      source: "vcard",
      source_file: filename,
      imported_at: Time.current
    }

    # UID - required field
    data[:uid] = get_property_value(properties, "UID") ||
                 get_property_value(properties, "X-ABUID") ||
                 SecureRandom.uuid

    # Name fields
    if properties["N"]
      # N field format: Family;Given;Additional;Prefix;Suffix
      name_parts = get_property_value(properties, "N").split(";")
      data[:family_name] = name_parts[0] if name_parts[0].present?
      data[:given_name] = name_parts[1] if name_parts[1].present?
      data[:middle_name] = name_parts[2] if name_parts[2].present?
      data[:name_prefix] = name_parts[3] if name_parts[3].present?
      data[:name_suffix] = name_parts[4] if name_parts[4].present?
    end

    data[:display_name] = get_property_value(properties, "FN")
    data[:nickname] = get_property_value(properties, "NICKNAME")

    # Organization
    if properties["ORG"]
      org_parts = get_property_value(properties, "ORG").split(";")
      data[:organization] = org_parts[0] if org_parts[0].present?
      data[:department] = org_parts[1] if org_parts[1].present?
    end

    data[:job_title] = get_property_value(properties, "TITLE")

    # Contact information
    data[:emails] = extract_multi_values_with_prefixes(properties, "EMAIL")
    data[:phones] = extract_multi_values_with_prefixes(properties, "TEL")
    data[:urls] = extract_multi_values_with_prefixes(properties, "URL")

    # Address
    addresses = []

    # Look for exact ADR properties
    if properties["ADR"]
      addresses.concat(properties["ADR"].map { |addr_prop| parse_address(addr_prop[:value]) }.compact)
    end

    # Look for prefixed ADR properties (like ITEM1.ADR)
    properties.each do |prop_name, prop_values|
      if prop_name.include?(".") && prop_name.split(".").last == "ADR"
        addresses.concat(prop_values.map { |addr_prop| parse_address(addr_prop[:value]) }.compact)
      end
    end

    data[:address] = addresses.first if addresses.any?

    # Birthday
    if properties["BDAY"]
      begin
        bday_value = get_property_value(properties, "BDAY")
        data[:birthday] = parse_date(bday_value)
      rescue => e
        @warnings << "Could not parse birthday: #{e.message}"
      end
    end

    # Notes
    data[:notes] = get_property_value(properties, "NOTE")

    # Categories
    if properties["CATEGORIES"]
      data[:categories] = get_property_value(properties, "CATEGORIES")
    end

    # Last modified
    if properties["REV"]
      begin
        data[:last_modified] = Time.parse(get_property_value(properties, "REV"))
      rescue => e
        @warnings << "Could not parse last modified date: #{e.message}"
      end
    end

    # Photo/Avatar
    if properties["PHOTO"]
      photo_prop = properties["PHOTO"].first
      if photo_prop[:parameters]["VALUE"] == "URI"
        data[:photo_url] = photo_prop[:value]
      else
        # Base64 encoded image data
        begin
          data[:photo_data] = Base64.decode64(photo_prop[:value].gsub(/\s/, ""))
        rescue => e
          @warnings << "Could not decode photo data: #{e.message}"
        end
      end
    end

    # Social profiles (custom handling for common X- properties)
    social_profiles = {}
    properties.each do |prop_name, prop_values|
      case prop_name
      when "X-SOCIALPROFILE"
        prop_values.each do |prop|
          if prop[:parameters]["TYPE"]
            social_profiles[prop[:parameters]["TYPE"].downcase] = prop[:value]
          end
        end
      when /^X-(TWITTER|LINKEDIN|FACEBOOK|INSTAGRAM|GITHUB)/
        platform = prop_name.sub("X-", "").downcase
        social_profiles[platform] = get_property_value(properties, prop_name)
      end
    end
    data[:social_profiles] = social_profiles.to_json if social_profiles.any?

    data
  end

  def get_property_value(properties, name)
    return nil unless properties[name]
    properties[name].first[:value]
  end

  def get_property_value_with_prefixes(properties, name)
    # Look for exact match first
    if properties[name]
      return properties[name].first[:value]
    end

    # Look for prefixed versions
    properties.each do |prop_name, prop_values|
      if prop_name.include?(".") && prop_name.split(".").last == name
        return prop_values.first[:value]
      end
    end

    nil
  end

  def extract_multi_values(properties, name)
    return nil unless properties[name]

    values = properties[name].map { |prop| prop[:value] }.compact
    values.any? ? values.join(",") : nil
  end

  def extract_multi_values_with_prefixes(properties, name)
    values = []

    # Look for exact match first
    if properties[name]
      values.concat(properties[name].map { |prop| prop[:value] }.compact)
    end

    # Look for prefixed versions (like ITEM1.TEL, ITEM2.EMAIL, etc.)
    properties.each do |prop_name, prop_values|
      if prop_name.include?(".") && prop_name.split(".").last == name
        values.concat(prop_values.map { |prop| prop[:value] }.compact)
      end
    end

    values.any? ? values.join(",") : nil
  end

  def parse_address(address_value)
    # ADR format: POBox;Extended;Street;City;State;PostalCode;Country
    parts = address_value.split(";")

    address_components = {
      "po_box" => parts[0],
      "extended" => parts[1],
      "street" => parts[2],
      "city" => parts[3],
      "state" => parts[4],
      "postal_code" => parts[5],
      "country" => parts[6]
    }.reject { |k, v| v.blank? }

    if address_components.any?
      # Return as JSON for structured storage
      address_components.to_json
    else
      nil
    end
  end

  def parse_date(date_string)
    return nil if date_string.blank?

    # Handle various date formats
    case date_string
    when /^\d{4}-\d{2}-\d{2}$/ # YYYY-MM-DD
      Date.parse(date_string)
    when /^\d{4}\d{2}\d{2}$/ # YYYYMMDD
      Date.strptime(date_string, "%Y%m%d")
    when /^\d{2}\/\d{2}\/\d{4}$/ # MM/DD/YYYY
      Date.strptime(date_string, "%m/%d/%Y")
    when /^\d{2}-\d{2}-\d{4}$/ # MM-DD-YYYY
      Date.strptime(date_string, "%m-%d-%Y")
    else
      Date.parse(date_string) # Fallback to Ruby's parser
    end
  rescue ArgumentError
    nil
  end
end
