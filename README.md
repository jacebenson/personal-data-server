# Personal Data Server

A comprehensive Rails 8 application for managing, analyzing, and providing AI-accessible APIs for all your personal data. This self-hosted platform gives you complete control over your financial records, health data, communications, and more.

## 🎯 Project Overview

Personal Data Server is designed to be your central hub for all personal data management. It provides:

- **Secure Data Storage**: SQLite-based storage with full privacy control
- **Rich Web Interface**: Modern, responsive UI with dark/light mode support
- **Comprehensive APIs**: RESTful JSON endpoints designed for AI model integration
- **Data Import Tools**: Support for major export formats from popular services
- **Analytics & Insights**: Built-in visualization and analysis tools

## 🏗️ Architecture

- **Framework**: Ruby on Rails 8.0+ with modern conventions
- **Database**: SQLite (development/small deployments), PostgreSQL (production)
- **Frontend**: Tailwind CSS with Turbo for enhanced UX
- **Authentication**: Devise with custom user management
- **Background Jobs**: Solid Queue for data processing
- **Deployment**: Docker-ready with Kamal configuration

## 📊 Data Categories

### 💰 Financial Data
- **Bank Statements**: Transaction history with categorization and account summaries
- **Investment Portfolios**: Fidelity, Principal 401k, and other investment tracking
- **Social Security Earnings**: Complete SSA earnings history and projections
- **Amazon Orders**: Purchase history with trend analysis
- **Duplicate Detection**: Smart duplicate transaction identification and removal

### 🏥 Health Data
- **Medical Records**: HL7 CCD/CCDA XML import and parsing
- **Medications**: Current and historical medication tracking
- **Allergies**: Comprehensive allergy management
- **Vital Signs**: Weight, blood pressure, and other health metrics
- **Medical Problems**: Condition tracking and history
- **Immunizations**: Vaccination records and scheduling
- **Healthcare Encounters**: Visit history and provider information

### 📧 Personal Communications
- **Email Archives**: MBOX import with full message history
- **LinkedIn Messages**: Professional networking communication history
- **Contacts**: VCard import and contact management
- **Calendar Events**: ICS import and event tracking

### 📚 Additional Data Types
- **Digital Purchases**: App store, digital content tracking
- **Reading History**: Goodreads integration (planned)
- **Media Consumption**: YouTube, streaming service history (planned)

## 🚀 Features

### Web Interface
- **Dashboard**: Unified overview of all data categories
- **Responsive Design**: Mobile-friendly with Tailwind CSS
- **Dark/Light Mode**: Full theme support
- **Advanced Filtering**: Smart search and filtering across all data types
- **Data Visualization**: Charts and graphs for financial and health trends
- **Import Wizards**: Step-by-step data import processes

### API System
- **RESTful Design**: Clean, consistent API endpoints
- **AI-Optimized**: Structured for LLM and AI model consumption
- **Comprehensive Coverage**: Access to all data categories
- **Error Handling**: Robust error responses and validation
- **Authentication**: Secure access control

### Data Management
- **Smart Imports**: Automatic duplicate detection and data validation
- **Format Support**: CSV, XML, MBOX, VCard, ICS, and more
- **Data Integrity**: Comprehensive validation and error handling
- **Privacy First**: All data remains on your server

## 🛠️ Installation & Setup

### Prerequisites
- Ruby 3.4+ 
- Rails 8.0+
- SQLite 3+ (or PostgreSQL for production)
- Node.js (for asset compilation)

### Quick Start
```bash
# Clone the repository
git clone https://github.com/jacebenson/personal-data-server.git
cd personal-data-server

# you may need to install ruby on rails... 
# for me that's just mise install

# Install dependencies
bundle install
npm install  # if using npm for frontend assets

# Setup database
rails db:create db:migrate db:seed

# Start the development server
bin/dev  # Starts Rails server with asset compilation
```

### Production Deployment
```bash
# Using Docker with Kamal
kamal setup

# Or traditional deployment
RAILS_ENV=production rails db:migrate
RAILS_ENV=production rails assets:precompile
RAILS_ENV=production rails server
```

## 📥 Data Import Guide

### Financial Data
1. **Bank Statements**: 
   - Export CSV from your bank (Ally Bank format supported)
   - Visit `/financial/bank_statements` and upload
   - Automatic duplicate detection and categorization

2. **Investment Data**:
   - Fidelity: Export portfolio data as CSV
   - Principal 401k: Download transaction history
   - Upload at `/financial/fidelity_upload` or `/financial/principal_upload`

3. **Social Security**:
   - Download XML from SSA.gov
   - Import at `/personal/social_security_upload`

### Health Data
1. **Medical Records**:
   - Request HL7 CCD/CCDA files from healthcare providers
   - Upload at `/health/import`
   - Automatic parsing of medications, allergies, problems, etc.

### Personal Data
1. **Email Archives**:
   - Export MBOX files from Gmail, Outlook, etc.
   - Import at `/personal/emails_upload`

2. **Contacts**:
   - Export VCard files from phone/email provider
   - Import at `/personal/contacts_upload`

3. **Calendar**:
   - Export ICS files or add calendar URLs
   - Import at `/personal/calendar_upload`

## 🔌 API Documentation

### Base URL
```
http://localhost:3000/api/v1
```

### Authentication
Include authentication headers as required by your Rails authentication system.

### Key Endpoints

#### Overview
```
GET /api/v1/overview  # Complete data summary
```

#### Financial
```
GET /api/v1/financial                     # Financial overview
GET /api/v1/financial/bank_statements     # All transactions
GET /api/v1/financial/investments         # Investment portfolio
GET /api/v1/financial/social_security_earnings # SSA data
GET /api/v1/financial/amazon_orders       # Purchase history
```

#### Health
```
GET /api/v1/health              # Health overview
GET /api/v1/health/medications  # Medication history
GET /api/v1/health/allergies    # Allergy information
GET /api/v1/health/vital_signs  # Health metrics
GET /api/v1/health/problems     # Medical conditions
```

#### Personal
```
GET /api/v1/personal                 # Personal data overview
GET /api/v1/personal/communications  # Messages and emails
GET /api/v1/personal/contacts        # Contact directory
GET /api/v1/personal/calendar_events # Calendar data
```

### Response Format
```json
{
  "success": true,
  "data": {
    "summary": "...",
    "records": [...],
    "metadata": {...}
  },
  "message": "Optional message"
}
```

## 🧪 Testing

```bash
# Run full test suite
rails test

# Run specific test categories
rails test test/controllers/
rails test test/models/
rails test test/integration/
```

## 🔧 Configuration

### Environment Variables
```bash
# Development
RAILS_ENV=development
DATABASE_URL=sqlite3:storage/development.sqlite3

# Production
RAILS_ENV=production
DATABASE_URL=postgresql://user:pass@localhost/personal_data_server
SECRET_KEY_BASE=your_secret_key
```

### Application Settings
- Modify `config/application.rb` for Rails configuration
- Update `config/routes.rb` for custom routing
- Configure authentication in `config/initializers/devise.rb`

## 🛡️ Security & Privacy

- **Local First**: All data stored locally on your server
- **No Third-Party Access**: No data sharing with external services
- **Encrypted Storage**: Database encryption options available
- **Access Control**: User authentication and authorization
- **Data Validation**: Comprehensive input validation and sanitization

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📋 Data Sources

### Supported Export Formats
- **Financial**: Ally Bank CSV, Fidelity CSV, Principal CSV, SSA XML
- **Health**: HL7 CCD/CCDA XML, custom health data formats
- **Communications**: MBOX (Gmail, Outlook), LinkedIn exports
- **Contacts**: VCard from iPhone, Google, Outlook
- **Calendar**: ICS files, calendar URLs
- **Shopping**: Amazon order history CSV

### Getting Your Data
1. **Google/Gmail**: [Google Takeout](https://takeout.google.com)
2. **LinkedIn**: Account Settings > Privacy > Getting a copy of your data
3. **Amazon**: Your Account > Download order reports
4. **Healthcare**: Request from providers (usually Patient Portal)
5. **Social Security**: [SSA.gov](https://www.ssa.gov) > my Social Security account

## 📈 Roadmap

- [ ] Enhanced data visualization dashboards
- [ ] Machine learning insights and predictions
- [ ] Additional data source integrations
- [ ] Mobile app companion
- [ ] Advanced search and query capabilities
- [ ] Data export and backup tools
- [ ] Multi-user support for families

## � Documentation

For detailed development guidelines, architecture documentation, and additional resources:

- **[Development Guidelines](/.github/copilot-instructions.md)** - Comprehensive development standards and conventions
- **[Documentation](docs/)** - Additional project documentation including MCP integration guides
- **API Documentation** - Available via the built-in API explorer at `/api/docs`

## �📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- **Documentation**: Check the wiki for detailed guides
- **Issues**: Report bugs via GitHub Issues
- **Discussions**: Join GitHub Discussions for questions and ideas

---

**Personal Data Server** - Take control of your data, enhance your privacy, and build a comprehensive view of your digital life.
