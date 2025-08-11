#!/usr/bin/env ruby

# Load Rails environment
require_relative 'config/environment'

puts "=== Health Table Schema Analysis ==="
puts

# Define all health models
health_models = [
  HealthPatient,
  HealthAllergy,
  HealthMedication,
  HealthProblem,
  HealthImmunization,
  HealthVitalSign,
  HealthEncounter
]

health_models.each do |model|
  puts "## #{model.name}"
  puts "Table: #{model.table_name}"
  puts "Columns:"

  model.columns.each do |column|
    next if column.name.in?([ 'id', 'created_at', 'updated_at' ])

    type_info = case column.type
    when :string
      limit = column.limit ? "(#{column.limit})" : ""
      "string#{limit}"
    when :text
      "text"
    when :integer
      "integer"
    when :decimal
      precision = column.precision ? "#{column.precision}" : ""
      scale = column.scale ? ",#{column.scale}" : ""
      "decimal(#{precision}#{scale})"
    when :datetime
      "datetime"
    when :date
      "date"
    when :boolean
      "boolean"
    else
      column.type.to_s
    end

    null_info = column.null ? "null" : "not null"
    foreign_key = column.name.end_with?('_id') ? " (FK)" : ""

    puts "  - #{column.name}: #{type_info} #{null_info}#{foreign_key}"
  end

  # Show associations
  if model.reflect_on_all_associations.any?
    puts "Associations:"
    model.reflect_on_all_associations.each do |assoc|
      puts "  - #{assoc.name} (#{assoc.macro})"
    end
  end

  # Show sample count
  puts "Current record count: #{model.count}"

  puts
end

# Show sample data for each health model if any records exist
puts "=== Sample Data ==="
puts

health_models.each do |model|
  next if model.count == 0

  puts "## #{model.name} Sample Records:"
  sample = model.limit(3)

  if sample.any?
    # Get non-timestamp columns
    columns = model.columns.reject { |c| c.name.in?([ 'id', 'created_at', 'updated_at' ]) }

    sample.each_with_index do |record, index|
      puts "Record #{index + 1}:"
      columns.each do |column|
        value = record.send(column.name)
        next if value.blank?

        # Truncate long values
        display_value = value.to_s.length > 50 ? "#{value.to_s[0..47]}..." : value.to_s
        puts "  #{column.name}: #{display_value}"
      end
      puts
    end
  end
  puts
end

puts "=== Analysis Complete ==="
