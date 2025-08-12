class Api::V1::DocsController < Api::V1::BaseController
  skip_before_action :authenticate_api_user!, only: [:index]

  def index
    render_success({
      api_version: 'v1',
      description: 'Simplified Personal Data Server API for AI model context providers',
      base_url: request.base_url + '/api/v1',
      authentication: {
        method: 'HTTP Basic Authentication',
        description: 'Use your email and password for basic auth',
        required_for: 'All endpoints except /docs'
      },
      endpoints: {
        overview: {
          path: '/overview',
          method: 'GET',
          description: 'Recent and active data from all categories (health, communications, transactions)',
          returns: 'Recent health encounters, active medications/allergies/problems, recent emails/LinkedIn messages, recent Amazon orders'
        },
        health: {
          path: '/health',
          method: 'GET', 
          description: 'All health data with optional search functionality',
          parameters: {
            q: 'Search query to filter results (searches across allergens, medications, problems, providers, etc.)',
            limit: 'Maximum number of results per category (default: 50)'
          },
          returns: 'Patient info, allergies, medications, problems, immunizations, vital signs, encounters (all ordered Z-A)'
        },
        communications: {
          path: '/communications',
          method: 'GET',
          description: 'Email and LinkedIn messages with search functionality', 
          parameters: {
            q: 'Search query to filter by subject, sender, or content',
            limit: 'Maximum number of results per category (default: 50)'
          },
          returns: 'Emails and LinkedIn messages ordered by date Z-A (most recent first)'
        },
        transactions: {
          path: '/transactions', 
          method: 'GET',
          description: 'Amazon orders and bank statements with search functionality',
          parameters: {
            q: 'Search query to filter by item name, description, account, etc.',
            limit: 'Maximum number of results per category (default: 50)'
          },
          returns: 'Amazon orders and bank statements ordered by date Z-A (most recent first)'
        }
      },
      usage_notes: [
        'All data is ordered Z-A (reverse alphabetical/chronological - most recent first)',
        'Search is case-insensitive and uses LIKE pattern matching',
        'Limit parameter controls results per category, not total results',
        'Authentication required for all endpoints except /docs'
      ]
    })
  end
end
