--[[
Comprehensive Monitoring and Metrics Configuration for KumoMTA
Enterprise-grade monitoring with Prometheus metrics, health checks, and alerting
]]

local kumo = require 'kumo'

-- Monitoring Configuration
local MONITORING_CONFIG = {
  -- Metrics collection
  metrics = {
    enabled = true,
    port = 8000,
    path = '/metrics',
    collection_interval = '15s',
    retention_period = '30 days',
  },
  
  -- Health checks
  health_checks = {
    enabled = true,
    interval = '30s',
    timeout = '10s',
    max_failures = 3,
  },
  
  -- Alerting
  alerting = {
    enabled = true,
    webhook_url = 'http://alertmanager:9093/api/v1/alerts',
    email_notifications = false,
    slack_webhook = nil,
  },
  
  -- Performance thresholds
  thresholds = {
    delivery_rate = 0.85,      -- 85% minimum delivery rate
    bounce_rate = 0.05,        -- 5% maximum bounce rate
    rejection_rate = 0.03,     -- 3% maximum rejection rate
    queue_depth = 5000,        -- Maximum queue depth
    delivery_latency = 30,     -- Maximum delivery latency in seconds
    memory_usage = 0.8,        -- Maximum memory usage (80%)
    cpu_usage = 0.8,           -- Maximum CPU usage (80%)
    disk_usage = 0.85,         -- Maximum disk usage (85%)
  }
}

-- Custom metrics collection
local metrics = {
  -- Delivery metrics
  delivery_success = kumo.metrics.counter('messages_delivered_total', 'Total messages delivered successfully'),
  delivery_failure = kumo.metrics.counter('messages_delivery_failed_total', 'Total messages that failed delivery'),
  delivery_bounce = kumo.metrics.counter('messages_bounced_total', 'Total messages that bounced'),
  delivery_rejection = kumo.metrics.counter('messages_rejected_total', 'Total messages that were rejected'),
  
  -- Queue metrics
  queue_depth = kumo.metrics.gauge('queue_depth_current', 'Current number of messages in queue'),
  queue_processing_rate = kumo.metrics.counter('queue_processing_total', 'Total messages processed from queue'),
  
  -- Connection metrics
  connections_established = kumo.metrics.counter('connections_established_total', 'Total SMTP connections established'),
  connections_failed = kumo.metrics.counter('connections_failed_total', 'Total SMTP connection failures'),
  active_connections = kumo.metrics.gauge('connections_active_current', 'Current number of active connections'),
  
  -- Performance metrics
  delivery_duration = kumo.metrics.histogram('delivery_duration_seconds', 'Message delivery duration in seconds', {0.1, 0.5, 1.0, 2.0, 5.0, 10.0, 30.0, 60.0}),
  message_size = kumo.metrics.histogram('message_size_bytes', 'Message size in bytes', {1024, 10240, 102400, 1048576, 10485760}),
  
  -- Resource metrics
  memory_usage = kumo.metrics.gauge('memory_usage_bytes', 'Current memory usage in bytes'),
  cpu_usage = kumo.metrics.gauge('cpu_usage_percent', 'Current CPU usage percentage'),
  disk_usage = kumo.metrics.gauge('disk_usage_percent', 'Current disk usage percentage'),
  
  -- Business metrics
  active_tenants = kumo.metrics.gauge('tenants_active_current', 'Current number of active tenants'),
  active_campaigns = kumo.metrics.gauge('campaigns_active_current', 'Current number of active campaigns'),
  domains_managed = kumo.metrics.gauge('domains_managed_current', 'Current number of managed domains'),
}

-- Health check functions
local function check_delivery_health()
  local delivery_rate = metrics.delivery_success:get() / (metrics.delivery_success:get() + metrics.delivery_failure:get())
  local bounce_rate = metrics.delivery_bounce:get() / (metrics.delivery_success:get() + metrics.delivery_bounce:get())
  local rejection_rate = metrics.delivery_rejection:get() / (metrics.delivery_success:get() + metrics.delivery_rejection:get())
  
  local health = {
    status = 'healthy',
    checks = {},
    timestamp = os.time(),
  }
  
  -- Check delivery rate
  if delivery_rate < MONITORING_CONFIG.thresholds.delivery_rate then
    table.insert(health.checks, {
      name = 'delivery_rate',
      status = 'critical',
      message = 'Delivery rate below threshold',
      value = delivery_rate,
      threshold = MONITORING_CONFIG.thresholds.delivery_rate,
    })
    health.status = 'critical'
  end
  
  -- Check bounce rate
  if bounce_rate > MONITORING_CONFIG.thresholds.bounce_rate then
    table.insert(health.checks, {
      name = 'bounce_rate',
      status = 'warning',
      message = 'Bounce rate above threshold',
      value = bounce_rate,
      threshold = MONITORING_CONFIG.thresholds.bounce_rate,
    })
    if health.status ~= 'critical' then
      health.status = 'warning'
    end
  end
  
  -- Check rejection rate
  if rejection_rate > MONITORING_CONFIG.thresholds.rejection_rate then
    table.insert(health.checks, {
      name = 'rejection_rate',
      status = 'warning',
      message = 'Rejection rate above threshold',
      value = rejection_rate,
      threshold = MONITORING_CONFIG.thresholds.rejection_rate,
    })
    if health.status ~= 'critical' then
      health.status = 'warning'
    end
  end
  
  return health
end

local function check_queue_health()
  local current_queue_depth = metrics.queue_depth:get()
  
  local health = {
    status = 'healthy',
    checks = {},
    timestamp = os.time(),
  }
  
  -- Check queue depth
  if current_queue_depth > MONITORING_CONFIG.thresholds.queue_depth then
    table.insert(health.checks, {
      name = 'queue_depth',
      status = 'critical',
      message = 'Queue depth above threshold',
      value = current_queue_depth,
      threshold = MONITORING_CONFIG.thresholds.queue_depth,
    })
    health.status = 'critical'
  elseif current_queue_depth > MONITORING_CONFIG.thresholds.queue_depth * 0.8 then
    table.insert(health.checks, {
      name = 'queue_depth',
      status = 'warning',
      message = 'Queue depth approaching threshold',
      value = current_queue_depth,
      threshold = MONITORING_CONFIG.thresholds.queue_depth,
    })
    health.status = 'warning'
  end
  
  return health
end

local function check_resource_health()
  local memory_usage = metrics.memory_usage:get()
  local cpu_usage = metrics.cpu_usage:get()
  local disk_usage = metrics.disk_usage:get()
  
  local health = {
    status = 'healthy',
    checks = {},
    timestamp = os.time(),
  }
  
  -- Check memory usage
  if memory_usage > MONITORING_CONFIG.thresholds.memory_usage then
    table.insert(health.checks, {
      name = 'memory_usage',
      status = 'warning',
      message = 'Memory usage above threshold',
      value = memory_usage,
      threshold = MONITORING_CONFIG.thresholds.memory_usage,
    })
    health.status = 'warning'
  end
  
  -- Check CPU usage
  if cpu_usage > MONITORING_CONFIG.thresholds.cpu_usage then
    table.insert(health.checks, {
      name = 'cpu_usage',
      status = 'warning',
      message = 'CPU usage above threshold',
      value = cpu_usage,
      threshold = MONITORING_CONFIG.thresholds.cpu_usage,
    })
    if health.status ~= 'critical' then
      health.status = 'warning'
    end
  end
  
  -- Check disk usage
  if disk_usage > MONITORING_CONFIG.thresholds.disk_usage then
    table.insert(health.checks, {
      name = 'disk_usage',
      status = 'critical',
      message = 'Disk usage above threshold',
      value = disk_usage,
      threshold = MONITORING_CONFIG.thresholds.disk_usage,
    })
    health.status = 'critical'
  end
  
  return health
end

-- Comprehensive health check
local function perform_health_check()
  local delivery_health = check_delivery_health()
  local queue_health = check_queue_health()
  local resource_health = check_resource_health()
  
  local overall_health = {
    status = 'healthy',
    checks = {},
    timestamp = os.time(),
    summary = {
      delivery = delivery_health.status,
      queue = queue_health.status,
      resources = resource_health.status,
    }
  }
  
  -- Combine all health checks
  for _, check in ipairs(delivery_health.checks) do
    table.insert(overall_health.checks, check)
  end
  
  for _, check in ipairs(queue_health.checks) do
    table.insert(overall_health.checks, check)
  end
  
  for _, check in ipairs(resource_health.checks) do
    table.insert(overall_health.checks, check)
  end
  
  -- Determine overall status
  for _, check in ipairs(overall_health.checks) do
    if check.status == 'critical' then
      overall_health.status = 'critical'
      break
    elseif check.status == 'warning' then
      overall_health.status = 'warning'
    end
  end
  
  return overall_health
end

-- Alerting system
local function send_alert(alert)
  if not MONITORING_CONFIG.alerting.enabled then
    return
  end
  
  local alert_data = {
    labels = {
      alertname = alert.name,
      severity = alert.status,
      instance = 'kumomta',
      service = 'email_delivery',
    },
    annotations = {
      summary = alert.message,
      description = string.format('%s: %s (threshold: %s)', alert.name, alert.value, alert.threshold),
      timestamp = os.date('%Y-%m-%d %H:%M:%S'),
    },
    startsAt = os.date('%Y-%m-%dT%H:%M:%SZ'),
  }
  
  -- Send to Alertmanager
  if MONITORING_CONFIG.alerting.webhook_url then
    local http = require 'http'
    local response = http.post(MONITORING_CONFIG.alerting.webhook_url, {
      headers = { 'Content-Type' = 'application/json' },
      body = json.encode({ alerts = { alert_data } }),
    })
    
    if response.status_code ~= 200 then
      kumo.log.error('Failed to send alert to Alertmanager', {
        status_code = response.status_code,
        response = response.body,
      })
    end
  end
  
  -- Log alert locally
  kumo.log.warn('Alert triggered', alert)
end

-- Metrics collection functions
local function collect_delivery_metrics(msg, result)
  if result == 'delivered' then
    metrics.delivery_success:inc()
    
    -- Record delivery duration
    local delivery_time = os.time() - (msg:get_meta('received_at') or os.time())
    metrics.delivery_duration:observe(delivery_time)
    
    -- Record message size
    local message_size = msg:get_meta('size') or 0
    metrics.message_size:observe(message_size)
    
  elseif result == 'bounced' then
    metrics.delivery_bounce:inc()
  elseif result == 'rejected' then
    metrics.delivery_rejection:inc()
  else
    metrics.delivery_failure:inc()
  end
end

local function collect_queue_metrics()
  -- Update queue depth metric
  local queue_depth = kumo.queue.get_depth()
  metrics.queue_depth:set(queue_depth)
  
  -- Update processing rate
  metrics.queue_processing_rate:inc()
end

local function collect_connection_metrics(connection_event, metadata)
  if connection_event == 'established' then
    metrics.connections_established:inc()
    metrics.active_connections:inc()
  elseif connection_event == 'closed' then
    metrics.active_connections:dec()
  elseif connection_event == 'failed' then
    metrics.connections_failed:inc()
  end
end

local function collect_resource_metrics()
  -- Memory usage
  local memory_info = kumo.memory.get_usage()
  metrics.memory_usage:set(memory_info.used_bytes)
  
  -- CPU usage (if available)
  local cpu_info = kumo.cpu.get_usage()
  if cpu_info then
    metrics.cpu_usage:set(cpu_info.usage_percent)
  end
  
  -- Disk usage
  local disk_info = kumo.disk.get_usage('/var/spool/kumomta')
  if disk_info then
    metrics.disk_usage:set(disk_info.usage_percent)
  end
end

-- Business metrics collection
local function collect_business_metrics()
  -- Active tenants
  local active_tenants = kumo.tenant.get_active_count()
  metrics.active_tenants:set(active_tenants)
  
  -- Active campaigns
  local active_campaigns = kumo.campaign.get_active_count()
  metrics.active_campaigns:set(active_campaigns)
  
  -- Managed domains
  local managed_domains = kumo.domain.get_managed_count()
  metrics.domains_managed:set(managed_domains)
end

-- Event handlers for metrics collection
kumo.on('smtp_server_message_received', function(msg)
  -- Record message received
  msg:set_meta('received_at', os.time())
  msg:set_meta('size', msg:get_size())
end)

kumo.on('message_delivered', function(msg, result)
  collect_delivery_metrics(msg, result)
end)

kumo.on('smtp_server_connection_accepted', function(conn_meta)
  collect_connection_metrics('established', conn_meta)
end)

kumo.on('smtp_server_connection_closed', function(conn_meta)
  collect_connection_metrics('closed', conn_meta)
end)

kumo.on('smtp_server_connection_failed', function(conn_meta)
  collect_connection_metrics('failed', conn_meta)
end)

-- Scheduled metrics collection
kumo.on('init', function()
  -- Collect metrics every 15 seconds
  kumo.timer('metrics_collection', '15s', function()
    collect_queue_metrics()
    collect_resource_metrics()
    collect_business_metrics()
  end)
  
  -- Perform health checks every 30 seconds
  kumo.timer('health_check', '30s', function()
    local health = perform_health_check()
    
    -- Send alerts for critical issues
    for _, check in ipairs(health.checks) do
      if check.status == 'critical' or check.status == 'warning' then
        send_alert(check)
      end
    end
    
    -- Log health status
    if health.status == 'critical' then
      kumo.log.error('Health check critical', health)
    elseif health.status == 'warning' then
      kumo.log.warn('Health check warning', health)
    else
      kumo.log.info('Health check passed', health)
    end
  end)
  
  -- Generate performance report every hour
  kumo.timer('performance_report', '1h', function()
    local report = {
      timestamp = os.time(),
      period = '1h',
      metrics = {
        delivery_success = metrics.delivery_success:get(),
        delivery_failure = metrics.delivery_failure:get(),
        delivery_bounce = metrics.delivery_bounce:get(),
        delivery_rejection = metrics.delivery_rejection:get(),
        queue_depth = metrics.queue_depth:get(),
        active_connections = metrics.active_connections:get(),
        memory_usage = metrics.memory_usage:get(),
        cpu_usage = metrics.cpu_usage:get(),
        disk_usage = metrics.disk_usage:get(),
      },
      health = perform_health_check(),
    }
    
    -- Log performance report
    kumo.log.info('Performance report generated', report)
    
    -- Send to monitoring system if configured
    if MONITORING_CONFIG.alerting.webhook_url then
      local http = require 'http'
      http.post(MONITORING_CONFIG.alerting.webhook_url .. '/reports', {
        headers = { 'Content-Type' = 'application/json' },
        body = json.encode(report),
      })
    end
  end)
end)

-- HTTP endpoints for monitoring
kumo.on('http_request', function(request)
  local path = request.path
  local method = request.method
  
  -- Health check endpoint
  if path == '/health' and method == 'GET' then
    local health = perform_health_check()
    return {
      status = 200,
      headers = { 'Content-Type' = 'application/json' },
      body = json.encode(health),
    }
  end
  
  -- Metrics endpoint
  if path == '/metrics' and method == 'GET' then
    local metrics_data = {}
    
    -- Collect all metrics
    for name, metric in pairs(metrics) do
      if metric.get then
        metrics_data[name] = metric:get()
      end
    end
    
    return {
      status = 200,
      headers = { 'Content-Type' = 'application/json' },
      body = json.encode(metrics_data),
    }
  end
  
  -- Status endpoint
  if path == '/status' and method == 'GET' then
    local status = {
      status = 'operational',
      timestamp = os.time(),
      version = 'enterprise-1.0',
      uptime = kumo.get_uptime(),
      health = perform_health_check(),
      metrics = {
        queue_depth = metrics.queue_depth:get(),
        active_connections = metrics.active_connections:get(),
        delivery_rate = metrics.delivery_success:get() / (metrics.delivery_success:get() + metrics.delivery_failure:get()),
      }
    }
    
    return {
      status = 200,
      headers = { 'Content-Type' = 'application/json' },
      body = json.encode(status),
    }
  end
  
  -- 404 for unknown endpoints
  return {
    status = 404,
    headers = { 'Content-Type' = 'text/plain' },
    body = 'Not Found',
  }
end)

print("🚀 Comprehensive Monitoring Configuration loaded successfully!")
print("✨ Features enabled:")
print("   • Prometheus Metrics Collection")
print("   • Real-time Health Monitoring")
print("   • Advanced Alerting System")
print("   • Performance Reporting")
print("   • Resource Usage Tracking")
print("   • Business Metrics Collection")
print("   • HTTP Monitoring Endpoints")
print("   • Automated Health Checks")
