# Personal Data Server

A Rails application for managing and analyzing personal data including health records, financial information, and personal communications.

## Features

- **Health Data Management**: Import and manage health records from HL7 CCD/CCDA XML files
- **Financial Tracking**: Bank statements, investments, Social Security earnings, Amazon orders
- **Personal Communications**: Email archives, LinkedIn messages, contacts, calendar events
- **RESTful API**: JSON API endpoints for AI model context providers and external integrations

## API Documentation

The application provides comprehensive JSON API endpoints designed for AI model context providers and external applications.

### Base URL
```
http://localhost:3000/api/v1
```

### Authentication
All API endpoints require user authentication. Include authentication headers as required by your Rails authentication system.

### Endpoints

#### Overview
Get a summary of all data categories:
```
GET /api/v1/overview
```

Returns user info, summary statistics for all categories, and available endpoints.

#### Health Data
```
GET /api/v1/health              # Complete health overview
GET /api/v1/health/allergies    # Patient allergies
GET /api/v1/health/medications  # Current and past medications  
GET /api/v1/health/problems     # Medical problems/conditions
GET /api/v1/health/immunizations # Vaccination records
GET /api/v1/health/vital_signs  # Vital sign measurements
GET /api/v1/health/encounters   # Healthcare visits
```

#### Financial Data  
```
GET /api/v1/financial                    # Financial overview
GET /api/v1/financial/bank_statements    # Bank transactions
GET /api/v1/financial/investments        # Investment portfolio
GET /api/v1/financial/social_security_earnings # SSA earnings history
GET /api/v1/financial/amazon_orders      # Amazon purchase history
```

#### Personal Data
```
GET /api/v1/personal                 # Personal data overview
GET /api/v1/personal/communications  # Combined emails and LinkedIn messages
GET /api/v1/personal/contacts        # Contact directory
GET /api/v1/personal/calendar_events # Calendar events
GET /api/v1/personal/emails          # Email messages only
GET /api/v1/personal/linkedin_messages # LinkedIn messages only
```

### Response Format
All API responses follow a consistent format:
```json
{
  "success": true,
  "data": {
    // Response data
  },
  "message": "Optional message"
}
```

Error responses:
```json
{
  "success": false,
  "error": "Error message"
}
```

### Example API Usage

#### Get health overview:
```bash
curl -H "Accept: application/json" \
     -H "Authorization: Bearer YOUR_TOKEN" \
     http://localhost:3000/api/v1/health
```

#### Get financial summary:
```bash
curl -H "Accept: application/json" \
     -H "Authorization: Bearer YOUR_TOKEN" \
     http://localhost:3000/api/v1/financial
```

## Setup and Installation

* Ruby version: 3.x+
* Rails version: 8.0+
* Database: SQLite (development), PostgreSQL (production)

```bash
# Clone the repository
git clone [repository_url]
cd personal-data-server

# Install dependencies
bundle install

# Setup database
rails db:create db:migrate

# Start the server
rails server
```

## Data Import

### Health Data
Import HL7 CCD/CCDA XML files through the web interface at `/health/import` or via API.

### Financial Data
- **Bank Statements**: Upload CSV files from Ally Bank and other institutions
- **Investments**: Import Fidelity portfolio data and Principal 401k transactions
- **Social Security**: Upload SSA earnings XML files
- **Amazon Orders**: Import retail order history CSV files

### Personal Data
- **Email**: Import MBOX archives from email providers
- **LinkedIn**: Upload LinkedIn connection and message exports
- **Contacts**: Import VCard files from various sources
- **Calendar**: Import ICS files or add calendar URLs

## Where to get data

### Content

1. Goodreads
    - https://help.goodreads.com/s/article/How-do-I-get-a-copy-of-my-data-from-Goodreads
    - https://www.goodreads.com/user/edit?tab=Settings, then request a data export
2. Youtube Views
