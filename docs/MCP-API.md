# MCP API Implementation Plan

## Overview

This document outlines the implementation of MCP (Model Context Protocol) specific API endpoints for the Personal Data Server. Based on David Gomes' talk about building effective MCP servers, this API is designed specifically for LLM consumption with action-oriented endpoints rather than traditional CRUD operations.

## Design Principles

1. **Action-Oriented**: Each endpoint represents a specific task/action an LLM wants to perform
2. **Limited Choices**: Focused set of essential tools (8-12 core actions) to avoid overwhelming LLMs
3. **LLM-Friendly**: Clear, direct descriptions with examples and context
4. **Purpose-Built**: Designed specifically for LLM consumption, not just exposing database operations
5. **Consistent Structure**: All responses follow the same MCP format
6. **Context-Aware**: Responses include context and suggested next actions

## Authentication

- **Method**: HTTP Basic Authentication
- **Implementation**: Use existing Rails authentication system
- **Headers**: `Authorization: Basic <base64(username:password)>`

## Request Format

- **Method**: POST for all endpoints (even read operations)
- **Content-Type**: `application/json`
- **Body**: JSON with query parameters

## Response Format

All endpoints return a consistent JSON structure:

```json
{
  "success": true|false,
  "action": "action_name",
  "result": { /* action-specific data */ },
  "context": "Human readable description of what was found/done",
  "suggested_next_actions": ["action1", "action2"],
  "timestamp": "2025-08-18T10:30:00Z"
}
```

Error responses:
```json
{
  "success": false,
  "action": "action_name",
  "error": "Error description",
  "suggestions": ["suggestion1", "suggestion2"],
  "timestamp": "2025-08-18T10:30:00Z"
}
```

## Date/Time Handling

### Supported Time Expressions
- **Specific dates**: `"2024-01-15"`, `"2024-01-15 14:30"`
- **Human expressions**: 
  - `"recent"` = last 3 months
  - `"today"` = current day
  - `"yesterday"` = previous day
  - `"this week"` = current week
  - `"last week"` = previous week
  - `"this month"` = current month
  - `"last month"` = previous month
  - `"this year"` = current year
  - `"last year"` = previous year

### Implementation
Create a `TimeExpressionParser` service to handle human-readable time expressions.

## Core MCP Endpoints

### 1. Universal Search
**Endpoint**: `POST /api/v1/mcp/search_all_data`

**Purpose**: Search across all personal data types

**Request**:
```json
{
  "query": "AI In A Box",
  "timeframe": "recent",
  "data_types": ["communications", "financial", "health", "calendar"]
}
```

**Response**:
```json
{
  "success": true,
  "action": "search_all_data",
  "result": {
    "query": "AI In A Box",
    "total_matches": 15,
    "communications": [...],
    "financial": [...],
    "health": [...],
    "calendar": [...]
  },
  "context": "Found 15 matches across 3 data types for 'AI In A Box'",
  "suggested_next_actions": ["find_person_contact", "get_conversation_history"]
}
```

### 2. Find Person Contact
**Endpoint**: `POST /api/v1/mcp/find_person_contact`

**Purpose**: Locate contact information and recent interactions

**Request**:
```json
{
  "name": "Kali Alexander",
  "include_history": true
}
```

### 3. Financial Summary
**Endpoint**: `POST /api/v1/mcp/get_financial_summary`

**Purpose**: Get comprehensive financial overview

**Request**:
```json
{
  "timeframe": "recent",
  "include_forecasts": true,
  "categories": ["savings", "spending", "investments"]
}
```

### 4. Analyze Spending Pattern
**Endpoint**: `POST /api/v1/mcp/analyze_spending_pattern`

**Purpose**: Deep dive into spending habits

**Request**:
```json
{
  "category": "dining",
  "timeframe": "last month",
  "compare_to": "last year"
}
```

### 5. Find Recent Mentions
**Endpoint**: `POST /api/v1/mcp/find_recent_mentions`

**Purpose**: Find mentions of topics/terms in communications

**Request**:
```json
{
  "term": "licensing",
  "timeframe": "recent",
  "sources": ["email", "linkedin", "messages"]
}
```

### 6. Get Conversation History
**Endpoint**: `POST /api/v1/mcp/get_conversation_history`

**Purpose**: Retrieve conversation history with specific person

**Request**:
```json
{
  "person_name": "John Doe",
  "timeframe": "last month",
  "limit": 20,
  "include_context": true
}
```

### 7. Calculate Savings Potential
**Endpoint**: `POST /api/v1/mcp/calculate_savings_potential`

**Purpose**: Identify opportunities to save money

**Request**:
```json
{
  "timeframe": "recent",
  "focus_categories": ["subscriptions", "dining", "entertainment"]
}
```

### 8. Discover Content Recommendations
**Endpoint**: `POST /api/v1/mcp/discover_content_recommendations`

**Purpose**: Get personalized content recommendations

**Request**:
```json
{
  "content_type": "books",
  "mood": "learning",
  "timeframe": "recent",
  "based_on": "reading_history"
}
```

### 9. Analyze Health Trends
**Endpoint**: `POST /api/v1/mcp/analyze_health_trends`

**Purpose**: Review health data patterns

**Request**:
```json
{
  "metrics": ["weight", "sleep", "activity"],
  "timeframe": "last 3 months",
  "include_recommendations": true
}
```

### 10. Find Favorite Media
**Endpoint**: `POST /api/v1/mcp/find_favorite_media`

**Purpose**: Discover favorite content from specific time periods

**Request**:
```json
{
  "media_type": "videos",
  "timeframe": "2020",
  "sort_by": "rating",
  "limit": 10
}
```

## Implementation Tasks

### Phase 1: Core Infrastructure
1. **Create MCP namespace in routes** (`config/routes.rb`)
2. **Implement base MCP controller** (`app/controllers/api/v1/mcp/base_controller.rb`)
3. **Create TimeExpressionParser service** (`app/services/time_expression_parser.rb`)
4. **Add authentication middleware** for MCP endpoints
5. **Create MCP response helpers** and error handling

### Phase 2: Core Actions (Priority endpoints)
1. **Universal Search** - `search_all_data`
2. **Find Person Contact** - `find_person_contact`
3. **Financial Summary** - `get_financial_summary`
4. **Find Recent Mentions** - `find_recent_mentions`

### Phase 3: Advanced Actions
1. **Spending Analysis** - `analyze_spending_pattern`
2. **Conversation History** - `get_conversation_history`
3. **Savings Calculator** - `calculate_savings_potential`
4. **Content Discovery** - `discover_content_recommendations`

### Phase 4: Specialized Actions
1. **Health Trends** - `analyze_health_trends`
2. **Media Favorites** - `find_favorite_media`

### Phase 5: Testing & Optimization
1. **Create comprehensive test suite** for all MCP endpoints
2. **Implement "Evals"** - LLM-specific tests to ensure proper tool usage
3. **Performance optimization** for complex queries
4. **Documentation** and examples for LLM training

## File Structure

```
app/
  controllers/
    api/
      v1/
        mcp/
          base_controller.rb
          search_controller.rb
          communications_controller.rb
          financial_controller.rb
          health_controller.rb
          content_controller.rb
  services/
    mcp/
      time_expression_parser.rb
      universal_search_service.rb
      financial_analyzer_service.rb
      content_discovery_service.rb
  models/
    concerns/
      mcp_searchable.rb

test/
  controllers/
    api/
      v1/
        mcp/
          *_test.rb
  services/
    mcp/
      *_test.rb
  integration/
    mcp_api_test.rb
```

## Security Considerations

1. **Rate limiting** for MCP endpoints
2. **Input validation** for all query parameters
3. **Data sanitization** in responses
4. **Audit logging** for MCP API usage
5. **Scope limiting** - ensure users can only access their own data

## Performance Considerations

1. **Database indexing** for common search patterns
2. **Response caching** for expensive queries
3. **Query optimization** for complex searches
4. **Pagination** for large result sets
5. **Background processing** for time-intensive analyses

## Monitoring & Analytics

1. **Track endpoint usage** to identify most valuable tools
2. **Monitor response times** and optimize slow queries
3. **Log LLM interaction patterns** for future improvements
4. **Error tracking** and resolution

## Example LLM Interactions

### Question: "When was the last time I mentioned AI In A Box?"
**LLM calls**: `POST /api/v1/mcp/find_recent_mentions`
```json
{ "term": "AI In A Box", "timeframe": "recent" }
```

### Question: "Who was asking about licensing recently?"
**LLM calls**: `POST /api/v1/mcp/find_recent_mentions`
```json
{ "term": "licensing", "timeframe": "recent", "group_by": "person" }
```

### Question: "How can I reach Kali Alexander?"
**LLM calls**: `POST /api/v1/mcp/find_person_contact`
```json
{ "name": "Kali Alexander", "include_history": true }
```

### Question: "What do I have saved up?"
**LLM calls**: `POST /api/v1/mcp/get_financial_summary`
```json
{ "timeframe": "current", "focus": "savings" }
```

### Question: "What books should I listen to?"
**LLM calls**: `POST /api/v1/mcp/discover_content_recommendations`
```json
{ "content_type": "books", "format": "audio", "based_on": "preferences" }
```

### Question: "What videos were my favorite to watch in 2020?"
**LLM calls**: `POST /api/v1/mcp/find_favorite_media`
```json
{ "media_type": "videos", "timeframe": "2020", "sort_by": "rating" }
```

## Next Steps

1. Review and approve this implementation plan
2. Set up project timeline and milestones
3. Begin Phase 1 implementation
4. Create initial test cases for core functionality
5. Set up monitoring and logging infrastructure

This implementation follows David Gomes' guidance about creating purpose-built tools for LLMs rather than just exposing raw API operations, ensuring effective LLM interaction while maintaining the Rails application's structure and conventions.
