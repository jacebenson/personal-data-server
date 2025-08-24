# frozen_string_literal: true

# MCP Health Controller - handles health trend analysis
class Api::V1::Mcp::HealthController < Api::V1::Mcp::BaseController
  
  # Review health data patterns and trends
  # POST /api/v1/mcp/analyze_health_trends
  def analyze_health_trends
    metrics = @sanitized_params[:metrics] || %w[weight sleep activity]
    timeframe = @sanitized_params[:parsed_timeframe] || TimeExpressionParser.parse('last 3 months')
    include_recommendations = @sanitized_params[:include_recommendations] || true
    
    trends_data = {}
    
    # Analyze weight trends
    if metrics.include?('weight')
      trends_data[:weight] = analyze_weight_trends(timeframe)
    end
    
    # Analyze sleep trends
    if metrics.include?('sleep')
      trends_data[:sleep] = analyze_sleep_trends(timeframe)
    end
    
    # Analyze activity trends
    if metrics.include?('activity')
      trends_data[:activity] = analyze_activity_trends(timeframe)
    end
    
    # Generate recommendations if requested
    recommendations = include_recommendations ? generate_health_recommendations(trends_data) : []
    
    response_data = {
      timeframe: @sanitized_params[:timeframe] || 'last 3 months',
      metrics: metrics,
      trends: trends_data,
      recommendations: recommendations,
      include_recommendations: include_recommendations
    }
    
    context_message = build_health_trends_context(trends_data, timeframe)
    suggested_actions = ['get_financial_summary', 'discover_content_recommendations']
    
    render_success(response_data, context_message, suggested_actions)
  end

  private

  def analyze_weight_trends(timeframe)
    trend_data = {
      available: false,
      current_weight: nil,
      weight_change: nil,
      trend_direction: 'stable',
      data_points: 0,
      recent_entries: []
    }
    
    return trend_data unless defined?(HealthWeight)
    
    weight_scope = current_user.health_weights
    weight_scope = weight_scope.where(recorded_at: timeframe) if timeframe
    
    weights = weight_scope.order(:recorded_at)
    
    return trend_data if weights.empty?
    
    trend_data[:available] = true
    trend_data[:data_points] = weights.count
    trend_data[:current_weight] = weights.last.weight
    
    if weights.count > 1
      first_weight = weights.first.weight
      last_weight = weights.last.weight
      trend_data[:weight_change] = last_weight - first_weight
      
      # Calculate trend direction
      if trend_data[:weight_change] > 2
        trend_data[:trend_direction] = 'increasing'
      elsif trend_data[:weight_change] < -2
        trend_data[:trend_direction] = 'decreasing'
      else
        trend_data[:trend_direction] = 'stable'
      end
      
      # Calculate average weekly change if we have enough data
      if weights.count > 4
        weeks = (weights.last.recorded_at - weights.first.recorded_at) / 1.week
        trend_data[:average_weekly_change] = (trend_data[:weight_change] / weeks).round(2) if weeks > 0
      end
    end
    
    # Recent entries for context
    trend_data[:recent_entries] = weights.last(5).map do |weight|
      {
        date: weight.recorded_at.to_date,
        weight: weight.weight,
        notes: weight.notes
      }
    end
    
    trend_data
  end

  def analyze_sleep_trends(timeframe)
    trend_data = {
      available: false,
      average_sleep_hours: nil,
      sleep_quality_trend: 'stable',
      data_points: 0,
      recent_entries: []
    }
    
    return trend_data unless defined?(HealthSleep)
    
    sleep_scope = current_user.health_sleeps
    sleep_scope = sleep_scope.where(recorded_at: timeframe) if timeframe
    
    sleep_records = sleep_scope.order(:recorded_at)
    
    return trend_data if sleep_records.empty?
    
    trend_data[:available] = true
    trend_data[:data_points] = sleep_records.count
    
    # Calculate average sleep duration
    if sleep_records.respond_to?(:average) && sleep_records.first.respond_to?(:hours_slept)
      trend_data[:average_sleep_hours] = sleep_records.average(:hours_slept)&.round(1)
    end
    
    # Analyze sleep quality if available
    if sleep_records.first.respond_to?(:quality_rating)
      quality_ratings = sleep_records.where.not(quality_rating: nil).pluck(:quality_rating)
      if quality_ratings.any?
        trend_data[:average_quality_rating] = (quality_ratings.sum.to_f / quality_ratings.length).round(1)
        
        # Determine trend direction based on recent vs older ratings
        if quality_ratings.length > 4
          recent_avg = quality_ratings.last(quality_ratings.length / 2).sum.to_f / (quality_ratings.length / 2)
          older_avg = quality_ratings.first(quality_ratings.length / 2).sum.to_f / (quality_ratings.length / 2)
          
          if recent_avg > older_avg + 0.5
            trend_data[:sleep_quality_trend] = 'improving'
          elsif recent_avg < older_avg - 0.5
            trend_data[:sleep_quality_trend] = 'declining'
          end
        end
      end
    end
    
    # Recent entries
    trend_data[:recent_entries] = sleep_records.last(5).map do |sleep|
      entry = {
        date: sleep.recorded_at.to_date
      }
      entry[:hours_slept] = sleep.hours_slept if sleep.respond_to?(:hours_slept)
      entry[:quality_rating] = sleep.quality_rating if sleep.respond_to?(:quality_rating)
      entry[:notes] = sleep.notes if sleep.respond_to?(:notes)
      entry
    end
    
    trend_data
  end

  def analyze_activity_trends(timeframe)
    trend_data = {
      available: false,
      average_daily_activity: nil,
      activity_trend: 'stable',
      data_points: 0,
      recent_entries: []
    }
    
    return trend_data unless defined?(HealthActivity)
    
    activity_scope = current_user.health_activities
    activity_scope = activity_scope.where(recorded_at: timeframe) if timeframe
    
    activities = activity_scope.order(:recorded_at)
    
    return trend_data if activities.empty?
    
    trend_data[:available] = true
    trend_data[:data_points] = activities.count
    
    # Calculate average activity metrics
    if activities.first.respond_to?(:steps)
      avg_steps = activities.where.not(steps: nil).average(:steps)
      trend_data[:average_daily_steps] = avg_steps&.round(0)
    end
    
    if activities.first.respond_to?(:exercise_minutes)
      avg_exercise = activities.where.not(exercise_minutes: nil).average(:exercise_minutes)
      trend_data[:average_exercise_minutes] = avg_exercise&.round(0)
    end
    
    # Determine activity trend
    if activities.count > 7
      recent_week = activities.last(7)
      older_week = activities.first(7)
      
      if activities.first.respond_to?(:steps)
        recent_avg_steps = recent_week.where.not(steps: nil).average(:steps) || 0
        older_avg_steps = older_week.where.not(steps: nil).average(:steps) || 0
        
        if recent_avg_steps > older_avg_steps * 1.1
          trend_data[:activity_trend] = 'increasing'
        elsif recent_avg_steps < older_avg_steps * 0.9
          trend_data[:activity_trend] = 'decreasing'
        end
      end
    end
    
    # Recent entries
    trend_data[:recent_entries] = activities.last(5).map do |activity|
      entry = {
        date: activity.recorded_at.to_date
      }
      entry[:steps] = activity.steps if activity.respond_to?(:steps)
      entry[:exercise_minutes] = activity.exercise_minutes if activity.respond_to?(:exercise_minutes)
      entry[:notes] = activity.notes if activity.respond_to?(:notes)
      entry
    end
    
    trend_data
  end

  def generate_health_recommendations(trends_data)
    recommendations = []
    
    # Weight recommendations
    if trends_data[:weight]&.dig(:available)
      weight_trend = trends_data[:weight]
      
      case weight_trend[:trend_direction]
      when 'increasing'
        if weight_trend[:weight_change] > 5
          recommendations << {
            category: 'weight',
            priority: 'high',
            recommendation: 'Consider consulting with a healthcare provider about weight management strategies',
            reason: "Weight has increased by #{weight_trend[:weight_change].round(1)} lbs"
          }
        else
          recommendations << {
            category: 'weight',
            priority: 'medium',
            recommendation: 'Monitor portion sizes and consider increasing physical activity',
            reason: "Weight has increased by #{weight_trend[:weight_change].round(1)} lbs"
          }
        end
      when 'decreasing'
        if weight_trend[:weight_change] < -10
          recommendations << {
            category: 'weight',
            priority: 'high',
            recommendation: 'Consult with a healthcare provider about rapid weight loss',
            reason: "Weight has decreased by #{(-weight_trend[:weight_change]).round(1)} lbs"
          }
        else
          recommendations << {
            category: 'weight',
            priority: 'low',
            recommendation: 'Continue current healthy habits for weight management',
            reason: "Weight is trending downward in a healthy range"
          }
        end
      end
    end
    
    # Sleep recommendations
    if trends_data[:sleep]&.dig(:available)
      sleep_trend = trends_data[:sleep]
      
      if sleep_trend[:average_sleep_hours] && sleep_trend[:average_sleep_hours] < 7
        recommendations << {
          category: 'sleep',
          priority: 'high',
          recommendation: 'Aim for 7-9 hours of sleep per night by establishing a consistent bedtime routine',
          reason: "Currently averaging #{sleep_trend[:average_sleep_hours]} hours of sleep"
        }
      elsif sleep_trend[:sleep_quality_trend] == 'declining'
        recommendations << {
          category: 'sleep',
          priority: 'medium',
          recommendation: 'Review sleep environment and habits to improve sleep quality',
          reason: 'Sleep quality appears to be declining'
        }
      end
    end
    
    # Activity recommendations
    if trends_data[:activity]&.dig(:available)
      activity_trend = trends_data[:activity]
      
      if activity_trend[:average_daily_steps] && activity_trend[:average_daily_steps] < 8000
        recommendations << {
          category: 'activity',
          priority: 'medium',
          recommendation: 'Increase daily walking to reach 8,000-10,000 steps per day',
          reason: "Currently averaging #{activity_trend[:average_daily_steps]} steps per day"
        }
      elsif activity_trend[:activity_trend] == 'decreasing'
        recommendations << {
          category: 'activity',
          priority: 'medium',
          recommendation: 'Consider ways to increase physical activity throughout the day',
          reason: 'Activity levels appear to be declining'
        }
      end
      
      if activity_trend[:average_exercise_minutes] && activity_trend[:average_exercise_minutes] < 30
        recommendations << {
          category: 'activity',
          priority: 'medium',
          recommendation: 'Aim for at least 30 minutes of exercise most days of the week',
          reason: "Currently averaging #{activity_trend[:average_exercise_minutes]} minutes of exercise"
        }
      end
    end
    
    # General recommendations if no specific data available
    if recommendations.empty?
      recommendations << {
        category: 'general',
        priority: 'low',
        recommendation: 'Continue tracking health metrics to identify trends and opportunities',
        reason: 'Limited health data available for analysis'
      }
    end
    
    recommendations
  end

  def build_health_trends_context(trends_data, timeframe)
    available_metrics = trends_data.select { |_, data| data[:available] }.keys
    
    if available_metrics.empty?
      "No health data available for the specified timeframe"
    else
      timeframe_desc = describe_timeframe(@sanitized_params[:timeframe], timeframe)
      "Health trends analysis for #{timeframe_desc}: analyzed #{available_metrics.join(', ')} data"
    end
  end
end
