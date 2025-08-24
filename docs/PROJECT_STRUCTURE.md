# Project Structure

This document provides an overview of the Personal Data Server project structure.

## Root Directory

```
personal-data-server/
├── app/                    # Rails application code
│   ├── controllers/        # Application controllers
│   ├── models/            # Data models and business logic
│   ├── views/             # ERB templates
│   ├── services/          # Business logic services
│   └── jobs/              # Background job classes
├── bin/                   # Executable scripts
│   ├── dev                # Development server launcher
│   ├── rails              # Rails CLI
│   ├── cleanup            # Project cleanup script
│   └── ...
├── config/                # Application configuration
├── db/                    # Database files and migrations
├── docs/                  # Project documentation
│   ├── README.md          # Documentation index
│   ├── MCP.md             # MCP overview
│   └── MCP-API.md         # MCP API implementation
├── lib/                   # Library code and custom tasks
├── public/                # Static assets served by web server
├── test/                  # Test files (models, controllers, etc.)
└── tmp/                   # Temporary files and cache
```

## Key Directories

### `/app`
Main application code following Rails conventions:
- **controllers/**: Handle HTTP requests and responses
- **models/**: Database models and business logic
- **views/**: ERB templates for HTML output
- **services/**: Complex business operations
- **jobs/**: Background processing tasks

### `/docs`
Project documentation:
- Development guides and API documentation
- MCP (Model Context Protocol) integration documentation

### `/bin`
Executable scripts:
- `dev`: Start development server with live reloading
- `cleanup`: Clean temporary files and logs
- Standard Rails executables (rails, rake, etc.)

### `/config`
Application configuration:
- Database configuration
- Route definitions
- Environment-specific settings
- Application secrets and credentials

### `/test`
Test suite organized by component type:
- Unit tests for models and services
- Controller tests for HTTP endpoints
- Integration tests for full application flows

## File Organization Principles

1. **Follow Rails conventions** for predictable structure
2. **Keep domain logic organized** by data category (financial, health, etc.)
3. **Separate concerns** between controllers, models, and services
4. **Document complex features** in the `/docs` directory
5. **Use services** for operations that span multiple models

## Development Tools

- **bin/dev**: Start development server with asset compilation
- **bin/cleanup**: Clean temporary files and large logs
- **rails console**: Interactive Ruby environment (use test files instead)
- **rails test**: Run the test suite
