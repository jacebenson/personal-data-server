# frozen_string_literal: true

# Controller to serve OpenAPI/Swagger specification
class OpenapiController < ApplicationController
  def show
    render json: openapi_spec, content_type: 'application/json'
  end

  private

  def openapi_spec
    {
      openapi: "3.0.3",
      info: {
        title: "Personal Data Server API",
        description: "API for managing and searching personal data including communications, financial records, health data, and more. This API follows the Model Context Protocol (MCP) for enhanced AI integration.",
        version: "1.0.0",
        contact: {
          name: "Personal Data Server",
          url: "https://github.com/jacebenson/personal-data-server"
        }
      },
      servers: [
        {
          url: "/api/v1",
          description: "API v1"
        }
      ],
      security: [
        {
          BasicAuth: []
        },
        {
          BearerAuth: []
        }
      ],
      components: {
        securitySchemes: {
          BasicAuth: {
            type: "http",
            scheme: "basic",
            description: "HTTP Basic Authentication using username and password"
          },
          BearerAuth: {
            type: "http",
            scheme: "bearer",
            description: "Bearer token authentication using your personal API token"
          }
        },
        schemas: {
          MCPResponse: {
            type: "object",
            properties: {
              success: { type: "boolean" },
              action: { type: "string" },
              result: { type: "object" },
              context: { type: "string" },
              suggested_next_actions: {
                type: "array",
                items: { type: "string" }
              },
              timestamp: { type: "string", format: "date-time" }
            },
            required: ["success", "action", "timestamp"]
          },
          MCPError: {
            type: "object",
            properties: {
              success: { type: "boolean", enum: [false] },
              action: { type: "string" },
              error: { type: "string" },
              suggestions: {
                type: "array",
                items: { type: "string" }
              },
              timestamp: { type: "string", format: "date-time" }
            },
            required: ["success", "action", "error", "timestamp"]
          },
          SearchRequest: {
            type: "object",
            properties: {
              search: {
                type: "object",
                properties: {
                  query: { type: "string", description: "Search query terms" },
                  timeframe: { type: "string", description: "Time range like 'recent', 'today', 'this week', 'last month'" },
                  limit: { type: "integer", minimum: 1, maximum: 1000, default: 50 },
                  data_types: {
                    type: "array",
                    items: { type: "string" },
                    description: "Filter by data types: communications, financial, health, calendar, shopping"
                  },
                  include_context: { type: "boolean", default: false }
                }
              }
            }
          },
          ContactRequest: {
            type: "object",
            properties: {
              search: {
                type: "object",
                properties: {
                  name: { type: "string", description: "Person's name to search for" },
                  email: { type: "string", description: "Email address to search for" },
                  include_history: { type: "boolean", default: false }
                }
              }
            }
          },
          FinancialSummaryRequest: {
            type: "object",
            properties: {
              search: {
                type: "object",
                properties: {
                  timeframe: { type: "string", default: "recent" },
                  categories: {
                    type: "array",
                    items: { type: "string" },
                    description: "Categories to include: spending, income, investments"
                  },
                  include_forecasts: { type: "boolean", default: false }
                }
              }
            }
          }
        }
      },
      paths: {
        "/mcp/search_all_data": {
          post: {
            summary: "Search across all personal data",
            description: "Universal search endpoint that searches across communications, financial records, health data, calendar events, and shopping history.",
            tags: ["Core Actions"],
            requestBody: {
              required: true,
              content: {
                "application/json": {
                  schema: { "$ref": "#/components/schemas/SearchRequest" },
                  example: {
                    search: {
                      query: "ai in a box",
                      timeframe: "recent",
                      limit: 20,
                      data_types: ["communications", "calendar"]
                    }
                  }
                }
              }
            },
            responses: {
              "200": {
                description: "Search results",
                content: {
                  "application/json": {
                    schema: { "$ref": "#/components/schemas/MCPResponse" },
                    example: {
                      success: true,
                      action: "search_all_data",
                      result: {
                        total_matches: 15,
                        matches_by_type: {
                          communications: 5,
                          calendar: 10
                        },
                        results: []
                      },
                      context: "Found 15 matches across 2 data types",
                      suggested_next_actions: [
                        "Refine search with more specific terms",
                        "Filter by specific data type"
                      ],
                      timestamp: "2025-08-18T12:00:00Z"
                    }
                  }
                }
              },
              "400": {
                description: "Bad request",
                content: {
                  "application/json": {
                    schema: { "$ref": "#/components/schemas/MCPError" }
                  }
                }
              },
              "401": {
                description: "Unauthorized",
                content: {
                  "application/json": {
                    schema: { "$ref": "#/components/schemas/MCPError" }
                  }
                }
              }
            }
          }
        },
        "/mcp/find_person_contact": {
          post: {
            summary: "Find contact information for a person",
            description: "Search for contact information and communication history with a specific person.",
            tags: ["Core Actions"],
            requestBody: {
              required: true,
              content: {
                "application/json": {
                  schema: { "$ref": "#/components/schemas/ContactRequest" }
                }
              }
            },
            responses: {
              "200": {
                description: "Contact information found",
                content: {
                  "application/json": {
                    schema: { "$ref": "#/components/schemas/MCPResponse" }
                  }
                }
              }
            }
          }
        },
        "/mcp/get_financial_summary": {
          post: {
            summary: "Get financial summary and analysis",
            description: "Retrieve financial overview including spending patterns, income, and investment performance.",
            tags: ["Core Actions"],
            requestBody: {
              required: true,
              content: {
                "application/json": {
                  schema: { "$ref": "#/components/schemas/FinancialSummaryRequest" }
                }
              }
            },
            responses: {
              "200": {
                description: "Financial summary",
                content: {
                  "application/json": {
                    schema: { "$ref": "#/components/schemas/MCPResponse" }
                  }
                }
              }
            }
          }
        },
        "/mcp/find_recent_mentions": {
          post: {
            summary: "Find recent mentions of topics or people",
            description: "Search for recent mentions of specific topics, people, or keywords across communications.",
            tags: ["Core Actions"],
            requestBody: {
              required: true,
              content: {
                "application/json": {
                  schema: { "$ref": "#/components/schemas/SearchRequest" }
                }
              }
            },
            responses: {
              "200": {
                description: "Recent mentions found",
                content: {
                  "application/json": {
                    schema: { "$ref": "#/components/schemas/MCPResponse" }
                  }
                }
              }
            }
          }
        },
        "/mcp/analyze_spending_pattern": {
          post: {
            summary: "Analyze spending patterns and trends",
            description: "Analyze spending patterns across categories and time periods with trend analysis.",
            tags: ["Advanced Actions"],
            requestBody: {
              required: true,
              content: {
                "application/json": {
                  schema: { "$ref": "#/components/schemas/FinancialSummaryRequest" }
                }
              }
            },
            responses: {
              "200": {
                description: "Spending analysis",
                content: {
                  "application/json": {
                    schema: { "$ref": "#/components/schemas/MCPResponse" }
                  }
                }
              }
            }
          }
        },
        "/mcp/get_conversation_history": {
          post: {
            summary: "Get conversation history with a person",
            description: "Retrieve detailed conversation history and communication patterns with a specific person.",
            tags: ["Advanced Actions"],
            requestBody: {
              required: true,
              content: {
                "application/json": {
                  schema: { "$ref": "#/components/schemas/ContactRequest" }
                }
              }
            },
            responses: {
              "200": {
                description: "Conversation history",
                content: {
                  "application/json": {
                    schema: { "$ref": "#/components/schemas/MCPResponse" }
                  }
                }
              }
            }
          }
        },
        "/mcp/calculate_savings_potential": {
          post: {
            summary: "Calculate potential savings opportunities",
            description: "Analyze spending to identify potential savings opportunities and budget optimizations.",
            tags: ["Advanced Actions"],
            requestBody: {
              required: true,
              content: {
                "application/json": {
                  schema: { "$ref": "#/components/schemas/FinancialSummaryRequest" }
                }
              }
            },
            responses: {
              "200": {
                description: "Savings analysis",
                content: {
                  "application/json": {
                    schema: { "$ref": "#/components/schemas/MCPResponse" }
                  }
                }
              }
            }
          }
        },
        "/mcp/discover_content_recommendations": {
          post: {
            summary: "Discover content recommendations",
            description: "Find personalized content recommendations based on viewing history and preferences.",
            tags: ["Advanced Actions"],
            requestBody: {
              required: true,
              content: {
                "application/json": {
                  schema: { "$ref": "#/components/schemas/SearchRequest" }
                }
              }
            },
            responses: {
              "200": {
                description: "Content recommendations",
                content: {
                  "application/json": {
                    schema: { "$ref": "#/components/schemas/MCPResponse" }
                  }
                }
              }
            }
          }
        },
        "/mcp/analyze_health_trends": {
          post: {
            summary: "Analyze health trends and patterns",
            description: "Analyze health data trends including weight, sleep, medications, and vital signs.",
            tags: ["Specialized Actions"],
            requestBody: {
              required: true,
              content: {
                "application/json": {
                  schema: { "$ref": "#/components/schemas/SearchRequest" }
                }
              }
            },
            responses: {
              "200": {
                description: "Health trends analysis",
                content: {
                  "application/json": {
                    schema: { "$ref": "#/components/schemas/MCPResponse" }
                  }
                }
              }
            }
          }
        },
        "/mcp/find_favorite_media": {
          post: {
            summary: "Find favorite media and entertainment",
            description: "Discover favorite books, movies, TV shows, podcasts, and other media based on consumption patterns.",
            tags: ["Specialized Actions"],
            requestBody: {
              required: true,
              content: {
                "application/json": {
                  schema: { "$ref": "#/components/schemas/SearchRequest" }
                }
              }
            },
            responses: {
              "200": {
                description: "Favorite media analysis",
                content: {
                  "application/json": {
                    schema: { "$ref": "#/components/schemas/MCPResponse" }
                  }
                }
              }
            }
          }
        }
      },
      tags: [
        {
          name: "Core Actions",
          description: "Essential endpoints for basic data access and search functionality"
        },
        {
          name: "Advanced Actions", 
          description: "Advanced analytics and pattern analysis endpoints"
        },
        {
          name: "Specialized Actions",
          description: "Domain-specific analysis for health, media, and content"
        }
      ]
    }
  end
end
