# Database Migration History

This document tracks the evolution of the Personal Data Server database schema.

## Complete Migration Reset (August 23, 2025)

Performed a complete migration cleanup and reset to a single initial schema migration:

### What Was Done
1. **Backed up existing data and schema**
   - Created `db/full_database_backup.sql` with complete database dump  
   - Created `db/schema_backup.rb` with current schema
   - Moved all old migrations to `db/migrate_old/` for reference

2. **Created single initial migration**
   - Generated `20250823193205_initial_schema.rb` with complete current schema
   - Includes all tables, indexes, and foreign keys in logical order
   - Represents the exact current state without migration history baggage
   - **Updated**: Removed import tracking tables (`linkedin_imports`, `mbox_imports`, `vcard_imports`) as these were temporary tracking tables

3. **Reset database with clean migration**
   - Dropped and recreated development database
   - Applied single initial migration successfully
   - Verified schema matches previous state

### Migration Cleanup (Previous - August 23, 2025)

Before the complete reset, we had removed these redundant migrations:

#### Removed Create/Drop Pairs
- `20250807011610_create_transactions.rb` + `20250807060452_drop_transactions_table.rb`
- Email/LinkedIn/Contacts create migrations + `20250823191843_drop_deleted_tables.rb`

#### Removed Empty Migrations  
- `20250823173455_restructure_contacts_system.rb`
- `20250823174948_fix_contacts_table_structure.rb`

### Result
- **Before**: 31 individual migrations (after initial cleanup)
- **After**: 1 comprehensive initial schema migration
- **Removed**: 30 individual migration files  
- **Schema**: Identical - same final database structure
- **Benefits**: Faster setup, cleaner history, easier maintenance

## Current Schema Organization

The single initial migration creates a complete database schema organized by domains:

### Core System
- `users` - User accounts and authentication with privacy/timezone settings
- `active_storage_*` - Rails file attachment system

### Financial Data
- `bank_statements` - Bank transaction history with duplicate prevention
- `investments` - Investment portfolio data with settlement tracking
- `social_security_earnings` - SSA earnings records by year
- `amazon_orders` - Amazon purchase history (retail + digital) with detailed order tracking

### Personal Data & Calendar
- `calendars` - Calendar sources with sync configuration
- `calendar_events` - Calendar entries with recurrence and attendee support

### Entertainment & Media
- `entertainment_contents` - Media consumption with Goodreads book integration
- `podcast_feeds` - Podcast subscriptions with sync management
- `podcast_episodes` - Individual podcast episodes with listen tracking

### Health Data
- `health_patients` - Patient information
- `health_allergies` - Allergy records with severity tracking
- `health_medications` - Medication history with prescriber info
- `health_problems` - Medical conditions with onset/resolution tracking
- `health_immunizations` - Vaccination records
- `health_vital_signs` - Health metrics over time
- `health_encounters` - Medical visits and provider information
- `health_sleep_data` - Sleep tracking (ResMed CPAP integration)

### Miscellaneous
- `null_edge_attendees` - Event attendance tracking

## Removed Tables (No Longer Needed)
- `linkedin_imports` - LinkedIn contact import tracking (removed from initial schema)
- `mbox_imports` - Email archive import tracking (removed from initial schema)
- `vcard_imports` - VCard contact import tracking (removed from initial schema)

*These import tracking tables were temporary and have been removed to simplify the schema.*

## Setup Instructions

### For New Installations
```bash
rails db:create db:migrate db:seed
```

### For Existing Installations
The database will work normally. If you need to reset to clean migration history:
```bash
# Backup your data first!
rails db:drop db:create db:migrate
# Then restore your data from backups
```

### Schema Loading (Recommended for Fresh Installs)
```bash
rails db:schema:load db:seed
```

## Migration Best Practices Going Forward

1. **Keep migrations simple** - One logical change per migration
2. **Test thoroughly** - Ensure migrations work in both directions  
3. **Document complex changes** - Add comments for business logic
4. **Avoid data migrations in schema migrations** - Use separate data migration scripts
5. **Regular maintenance** - Periodically review for cleanup opportunities
6. **Schema loading** - Use `rails db:schema:load` for fresh setups

## Backup Files

The following backup files are available for reference:
- `db/migrate_old/` - All previous individual migrations
- `db/full_database_backup.sql` - Complete SQLite database dump from before reset
- `db/schema_backup.rb` - Schema file from before reset

These can be removed once you're confident the reset was successful.
