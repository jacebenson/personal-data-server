# Personal Data Server - Copilot Instructions

## Project Overview

**Technology Stack**: Ruby on Rails 8.0.2, Ruby 3.4.2, SQLite3 3.50.4, Tailwind CSS 4.3.0, Turbo  
**Purpose**: Privacy-focused personal data management system  
**Data Policy**: All user data is private and never shared with third parties

## Architecture & Conventions

### Rails Structure
- **Controllers**: RESTful design, keep thin, delegate business logic to models/services
- **Models**: Business logic, validations, database relationships
- **Views**: ERB templates with Tailwind CSS styling
- **Services**: Complex business operations (`app/services/`)
- **Jobs**: Background processing for imports and long-running tasks (`app/jobs/`)

### Data Organization by Domain
- **Personal**: Personal information and documents
- **Shopping**: Purchase history and shopping data
- **Financial**: Financial records and transactions  
- **Health**: Health and wellness data
- **Dashboard**: Overview and analytics

## Development Guidelines

### Database (SQLite3)
- **Use SQLite3-compatible syntax only**
- **Case-insensitive searches**: `LIKE ... COLLATE NOCASE` (NOT `ILIKE`)
- **Testing**: Use `sqlite3` command or create test files in `test/` directory
- **No PostgreSQL syntax** - stick to SQLite3 features

### Frontend Standards
- **CSS Framework**: Tailwind CSS exclusively
- **JavaScript**: Minimal usage - prefer server-side solutions
- **Turbo**: Use for enhanced UX without heavy JavaScript
- **Form Styling**: Use standard input classes: `"p-1 mt-1 block w-full rounded-md border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-white shadow-sm focus:border-blue-500 focus:ring-blue-500"`

### Code Organization
- **Partials**: Use for reusable components
  - Domain-specific: `app/views/[domain]/`
  - Shared across domains: `app/views/shared/`
- **Pagination**: Custom implementation (no kaminari)
- **Background Jobs**: For data imports and recurring tasks

## Development Workflow

### Server Management
- **Server is typically running** - do NOT start manually
- **Restart server**: `touch tmp/restart.txt`
- **Environment**: Development with live reloading

### Testing & Debugging
- **Run tests**: `rails test` (routes require authentication)
- **No `rails console`**: Use test files or direct SQLite3 queries
- **No browser testing**: Most routes are auth-protected

### File Operations
- **Follow Rails conventions** for naming and structure
- **Use appropriate tools**: File editing tools, not terminal commands for code changes
- **Read context first**: Understand existing patterns before making changes

## Specific Technical Requirements

### Database Queries
```ruby
# ✅ Correct (SQLite3)
User.where("name LIKE ? COLLATE NOCASE", "%john%")

# ❌ Incorrect (PostgreSQL)
User.where("name ILIKE ?", "%john%")
```

### Form Inputs
```erb
<%= text_field_tag :name, nil, class: "p-1 mt-1 block w-full rounded-md border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-white shadow-sm focus:border-blue-500 focus:ring-blue-500" %>
```

### Background Processing
- Use `app/jobs/` for any long-running operations
- Import jobs for external data processing
- Recurring lookup jobs for data updates

## Key Constraints
- **Privacy First**: No external data sharing
- **SQLite3 Only**: No PostgreSQL-specific features
- **Minimal JavaScript**: Server-side solutions preferred
- **Authentication Required**: Most routes are protected
- **Local Development**: No production server access needed
