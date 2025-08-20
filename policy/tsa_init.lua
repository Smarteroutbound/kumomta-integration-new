--[[
KumoMTA Traffic Shaping Automation (TSA) Daemon Configuration
Enterprise-grade automation for intelligent email delivery optimization
]]

local tsa = require 'tsa'

-- Initialize TSA daemon
tsa.on('tsa_init', function()
  print("🚀 Initializing Traffic Shaping Automation Daemon...")
  
  -- Start HTTP listener for communication with KumoMTA nodes
  tsa.start_http_listener {
    listen = '0.0.0.0:8008',
    trusted_hosts = { '127.0.0.1', '::1', '172.16.0.0/12', '192.168.0.0/16' },
  }
  
  -- Configure TSA behavior
  tsa.configure {
    -- How often to process events
    processing_interval = '30s',
    
    -- How long to keep historical data
    retention_period = '7 days',
    
    -- Maximum number of automation rules to apply simultaneously
    max_concurrent_rules = 100,
    
    -- Enable advanced analytics
    enable_analytics = true,
    
    -- Enable machine learning for pattern detection
    enable_ml_patterns = true,
    
    -- Configure alerting
    alerting = {
      enabled = true,
      webhook_url = 'http://monitoring:9093/api/v1/alerts',
      email_notifications = false,
    }
  }
  
  print("✅ TSA Daemon initialized successfully!")
end)

-- Configure traffic shaping data loading
tsa.on('tsa_load_shaping_data', function()
  local shaping = require 'kumo.shaping'
  
  -- Load the main shaping configuration
  local config = shaping.load {
    '/opt/kumomta/share/policy-extras/shaping.toml',
    '/opt/kumomta/etc/policy/shaping.toml',
  }
  
  return config
end)

-- Advanced automation rules for intelligent delivery optimization
tsa.on('tsa_process_event', function(event)
  local event_type = event.type
  local domain = event.domain
  local response = event.response
  local timestamp = event.timestamp
  
  -- Process delivery events for optimization
  if event_type == 'delivery' then
    -- Track successful deliveries
    tsa.track_metric('delivery_success', {
      domain = domain,
      timestamp = timestamp,
      value = 1,
    })
    
    -- Optimize delivery patterns for successful domains
    if event.delivery_time and event.delivery_time < 5 then
      -- Fast delivery - can increase rate slightly
      tsa.optimize_delivery_rate(domain, 'increase', 0.1)
    end
  end
  
  -- Process bounce events for reputation management
  if event_type == 'bounce' then
    -- Track bounce rates
    tsa.track_metric('bounce_rate', {
      domain = domain,
      timestamp = timestamp,
      value = 1,
    })
    
    -- Apply bounce-based optimizations
    if response:match('spam') or response:match('blocked') then
      -- Spam-related bounce - reduce rate significantly
      tsa.optimize_delivery_rate(domain, 'decrease', 0.5)
      tsa.suspend_domain(domain, '2 hours', 'spam_bounce')
    elseif response:match('rate limit') or response:match('too many') then
      -- Rate limit bounce - reduce rate moderately
      tsa.optimize_delivery_rate(domain, 'decrease', 0.3)
      tsa.suspend_domain(domain, '1 hour', 'rate_limit_bounce')
    else
      -- Other bounce - reduce rate slightly
      tsa.optimize_delivery_rate(domain, 'decrease', 0.1)
    end
  end
  
  -- Process rejection events
  if event_type == 'rejection' then
    -- Track rejection rates
    tsa.track_metric('rejection_rate', {
      domain = domain,
      timestamp = timestamp,
      value = 1,
    })
    
    -- Apply rejection-based optimizations
    if response:match('authentication') then
      -- Authentication issue - suspend tenant
      tsa.suspend_tenant(event.tenant, '3 hours', 'auth_rejection')
    elseif response:match('connection') then
      -- Connection issue - reduce connection limit
      tsa.reduce_connection_limit(domain, 0.5, '1 hour')
    end
  end
  
  -- Process tempfail events for retry optimization
  if event_type == 'tempfail' then
    -- Track temporary failures
    tsa.track_metric('tempfail_rate', {
      domain = domain,
      timestamp = timestamp,
      value = 1,
    })
    
    -- Apply tempfail-based optimizations
    if event.attempt_count and event.attempt_count > 3 then
      -- Multiple attempts - increase retry interval
      tsa.increase_retry_interval(domain, '2x')
    end
  end
  
  -- Process connection events for network optimization
  if event_type == 'connection' then
    if event.status == 'established' then
      -- Track connection success
      tsa.track_metric('connection_success', {
        domain = domain,
        timestamp = timestamp,
        value = 1,
      })
    elseif event.status == 'failed' then
      -- Track connection failures
      tsa.track_metric('connection_failure', {
        domain = domain,
        timestamp = timestamp,
        value = 1,
      })
      
      -- Apply connection failure optimizations
      if event.failure_reason == 'timeout' then
        tsa.increase_connection_timeout(domain, '2x')
      elseif event.failure_reason == 'refused' then
        tsa.suspend_domain(domain, '30 minutes', 'connection_refused')
      end
    end
  end
end)

-- Machine learning pattern detection for advanced optimization
tsa.on('tsa_analyze_patterns', function()
  -- Analyze delivery patterns for optimization opportunities
  local patterns = tsa.analyze_delivery_patterns()
  
  for domain, pattern in pairs(patterns) do
    -- Optimize based on time-of-day patterns
    if pattern.time_based_optimization then
      local hour = os.date('*t').hour
      if hour >= 9 and hour <= 17 then
        -- Business hours - increase rate
        tsa.optimize_delivery_rate(domain, 'increase', 0.2)
      else
        -- Off-hours - decrease rate
        tsa.optimize_delivery_rate(domain, 'decrease', 0.3)
      end
    end
    
    -- Optimize based on volume patterns
    if pattern.volume_based_optimization then
      if pattern.current_volume < pattern.optimal_volume * 0.5 then
        -- Low volume - can increase rate
        tsa.optimize_delivery_rate(domain, 'increase', 0.15)
      elseif pattern.current_volume > pattern.optimal_volume * 1.5 then
        -- High volume - decrease rate
        tsa.optimize_delivery_rate(domain, 'decrease', 0.2)
      end
    end
    
    -- Optimize based on reputation patterns
    if pattern.reputation_based_optimization then
      if pattern.reputation_score > 0.8 then
        -- High reputation - can increase rate
        tsa.optimize_delivery_rate(domain, 'increase', 0.1)
      elseif pattern.reputation_score < 0.3 then
        -- Low reputation - decrease rate significantly
        tsa.optimize_delivery_rate(domain, 'decrease', 0.6)
      end
    end
  end
end)

-- Health monitoring and alerting
tsa.on('tsa_health_check', function()
  local health = {
    status = 'healthy',
    timestamp = os.time(),
    version = 'enterprise-1.0',
    metrics = {},
    alerts = {},
  }
  
  -- Check key metrics
  local delivery_rate = tsa.get_metric('delivery_success', '24h')
  local bounce_rate = tsa.get_metric('bounce_rate', '24h')
  local rejection_rate = tsa.get_metric('rejection_rate', '24h')
  
  health.metrics.delivery_rate = delivery_rate
  health.metrics.bounce_rate = bounce_rate
  health.metrics.rejection_rate = rejection_rate
  
  -- Generate alerts based on thresholds
  if bounce_rate > 0.05 then -- 5%
    table.insert(health.alerts, {
      severity = 'warning',
      message = 'High bounce rate detected',
      value = bounce_rate,
      threshold = 0.05,
    })
  end
  
  if rejection_rate > 0.03 then -- 3%
    table.insert(health.alerts, {
      severity = 'warning',
      message = 'High rejection rate detected',
      value = rejection_rate,
      threshold = 0.03,
    })
  end
  
  if delivery_rate < 0.85 then -- 85%
    table.insert(health.alerts, {
      severity = 'critical',
      message = 'Low delivery rate detected',
      value = delivery_rate,
      threshold = 0.85,
    })
  end
  
  -- Update overall status based on alerts
  for _, alert in ipairs(health.alerts) do
    if alert.severity == 'critical' then
      health.status = 'critical'
      break
    elseif alert.severity == 'warning' then
      health.status = 'warning'
    end
  end
  
  return health
end)

-- Performance optimization and resource management
tsa.on('tsa_optimize_performance', function()
  -- Optimize memory usage
  local memory_usage = tsa.get_memory_usage()
  if memory_usage > 0.8 then -- 80%
    tsa.cleanup_old_data('1 day')
    tsa.reduce_analytics_depth('12 hours')
  end
  
  -- Optimize processing intervals based on load
  local event_rate = tsa.get_event_rate('1 minute')
  if event_rate > 1000 then
    -- High load - increase processing frequency
    tsa.set_processing_interval('15s')
  elseif event_rate < 100 then
    -- Low load - decrease processing frequency
    tsa.set_processing_interval('60s')
  end
  
  -- Optimize connection pooling
  local connection_utilization = tsa.get_connection_utilization()
  if connection_utilization > 0.9 then -- 90%
    tsa.increase_connection_pool_size(1.2)
  elseif connection_utilization < 0.3 then -- 30%
    tsa.decrease_connection_pool_size(0.8)
  end
end)

-- Custom automation rules for business logic
tsa.on('tsa_custom_automation', function(event)
  -- Business hours optimization
  local hour = os.date('*t').hour
  local is_business_hours = hour >= 9 and hour <= 17
  
  if is_business_hours then
    -- During business hours, be more aggressive
    tsa.set_global_optimization('business_hours', {
      delivery_rate_multiplier = 1.2,
      connection_limit_multiplier = 1.1,
      retry_interval_multiplier = 0.8,
    })
  else
    -- During off-hours, be more conservative
    tsa.set_global_optimization('off_hours', {
      delivery_rate_multiplier = 0.8,
      connection_limit_multiplier = 0.9,
      retry_interval_multiplier = 1.2,
    })
  end
  
  -- Weekend optimization
  local day_of_week = os.date('*t').wday
  local is_weekend = day_of_week == 1 or day_of_week == 7
  
  if is_weekend then
    tsa.set_global_optimization('weekend', {
      delivery_rate_multiplier = 0.7,
      connection_limit_multiplier = 0.8,
      retry_interval_multiplier = 1.5,
    })
  end
  
  -- Peak time optimization (lunch and end of day)
  if hour == 12 or hour == 17 then
    tsa.set_global_optimization('peak_time', {
      delivery_rate_multiplier = 0.9,
      connection_limit_multiplier = 0.95,
      retry_interval_multiplier = 1.1,
    })
  end
end)

-- Reporting and analytics
tsa.on('tsa_generate_report', function()
  local report = {
    timestamp = os.time(),
    period = '24h',
    summary = {},
    details = {},
    recommendations = {},
  }
  
  -- Generate summary statistics
  report.summary = {
    total_messages = tsa.get_metric('total_messages', '24h'),
    delivered_messages = tsa.get_metric('delivery_success', '24h'),
    bounced_messages = tsa.get_metric('bounce_rate', '24h'),
    rejected_messages = tsa.get_metric('rejection_rate', '24h'),
    delivery_rate = tsa.calculate_delivery_rate('24h'),
    average_delivery_time = tsa.get_average_delivery_time('24h'),
  }
  
  -- Generate detailed analysis
  report.details = {
    top_domains = tsa.get_top_domains('24h', 10),
    top_bounce_reasons = tsa.get_top_bounce_reasons('24h', 5),
    top_rejection_reasons = tsa.get_top_rejection_reasons('24h', 5),
    performance_metrics = tsa.get_performance_metrics('24h'),
  }
  
  -- Generate optimization recommendations
  report.recommendations = tsa.generate_optimization_recommendations('24h')
  
  -- Send report to monitoring system
  tsa.send_report(report)
  
  return report
end)

print("🚀 TSA Daemon Policy loaded successfully!")
print("✨ Advanced Features enabled:")
print("   • Machine Learning Pattern Detection")
print("   • Business Hours Optimization")
print("   • Reputation-Based Rate Adjustment")
print("   • Advanced Analytics and Reporting")
print("   • Intelligent Connection Pooling")
print("   • Custom Business Logic Automation")
print("   • Performance Self-Optimization")
print("   • Comprehensive Health Monitoring")
