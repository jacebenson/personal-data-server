# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts "🌱 Seeding Personal Data Server..."

# Create admin user for easy testing
admin_user = User.find_or_create_by!(email: "admin@example.com") do |user|
  user.password = "admin123"
  user.password_confirmation = "admin123"
  user.timezone = "Central Time (US & Canada)"
  user.setting_privacy_mode = false
end

puts "✅ Created admin user: #{admin_user.email}"
puts "   Password: admin123"
puts "   You can now log in and test the application!"
puts ""

# Load domain-specific seed files
seed_files = [
  'db/seeds/financial.rb',
  'db/seeds/health.rb',
  'db/seeds/entertainment.rb',
  'db/seeds/calendar.rb',
  'db/seeds/null_edge.rb'
]

seed_files.each do |seed_file|
  if File.exist?(seed_file)
    puts "📁 Loading #{seed_file}..."
    load seed_file
  else
    puts "⚠️  Seed file not found: #{seed_file}"
  end
end

# Seed all domains for the admin user
puts ""
puts "🚀 Seeding comprehensive demo data..."

if defined?(seed_financial_data)
  seed_financial_data(admin_user)
  puts ""
end

if defined?(seed_health_data)
  seed_health_data(admin_user)
  puts ""
end

if defined?(seed_entertainment_data)
  seed_entertainment_data(admin_user)
  puts ""
end

if defined?(seed_calendar_data)
  seed_calendar_data(admin_user)
  puts ""
end

if defined?(seed_null_edge_data)
  seed_null_edge_data(admin_user)
  puts ""
end

puts "🎯 Next steps:"
puts "   1. Start the server: bin/dev"
puts "   2. Visit http://localhost:3000"
puts "   3. Sign in with admin@example.com / admin123"
puts "   4. Explore all the demo data across different sections!"
puts ""

puts "🌱 Seeding complete! The admin user now has comprehensive demo data across all domains."
