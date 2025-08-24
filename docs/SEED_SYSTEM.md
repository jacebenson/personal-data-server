# Seed Data System

This project includes a comprehensive seed data system that creates realistic demo data across all application domains.

## Usage

To seed the database with demo data:

```bash
bin/rails db:seed
```

This will create:
- An admin user (admin@example.com / admin123)
- Comprehensive demo data across all domains

## Seed Files

The seed system is organized into domain-specific files:

- `db/seeds.rb` - Main seed file that coordinates all domains
- `db/seeds/financial.rb` - Bank transactions, investments, Social Security, Amazon orders
- `db/seeds/health.rb` - Patient records, medications, allergies, sleep data, vital signs
- `db/seeds/entertainment.rb` - Books, YouTube videos, Netflix shows, podcast feeds
- `db/seeds/calendar.rb` - Calendars and events (personal, work, health, family)
- `db/seeds/null_edge.rb` - Event attendance tracking data

## Demo Data Includes

### Financial Domain
- 32 realistic bank transactions across multiple accounts
- 12 investment transactions (buy/sell/dividend)
- 5 years of Social Security earnings records
- 3 Amazon orders (retail and digital)

### Health Domain
- 1 patient record with complete medical history
- 2 allergies with severity levels
- 3 current medications with dosing
- 3 health problems with ICD codes
- 3 immunizations with dates
- 6 vital sign records
- 3 medical encounters
- 30 days of CPAP sleep data

### Entertainment Domain
- 4 books with Goodreads-style data (ratings, shelves, ISBN)
- 3 YouTube video viewing records
- 2 Netflix show viewing history
- 3 podcast feeds with 9 episodes total

### Calendar Domain
- 4 calendars (Personal, Work, Health, Family)
- 13 calendar events (mix of past and future)
- Realistic event scheduling patterns

### Null Edge Domain
- 33 event attendance records over 90 days
- Realistic attendance patterns based on day of week
- Total of 1,186 tracked attendees across all events

## Admin User

The seed system creates an admin user for easy testing:

- **Email**: admin@example.com
- **Password**: admin123
- **Timezone**: Central Time (US & Canada)
- **Privacy Mode**: Disabled (for easier testing)

## Idempotent Design

All seed operations are idempotent - you can run `bin/rails db:seed` multiple times without creating duplicates. The system uses `find_or_create_by!` patterns to ensure data integrity.

## Development Notes

- Each domain seed file is self-contained with its own function
- Realistic data patterns based on actual usage scenarios
- Date ranges designed to show both historical and upcoming data
- Foreign key relationships properly maintained
- Validation-compliant data that passes all model validations

## Testing

After seeding, you can:

1. Start the server: `bin/dev`
2. Visit http://localhost:3000
3. Sign in with admin@example.com / admin123
4. Explore all sections to see the demo data

Each section of the application will have realistic, browseable data that demonstrates the full functionality of the Personal Data Server.
