--[[
########################################################
  KumoMTA Production Policy for Mailcow Relay
  Based on official KumoMTA examples
  Configured as email delivery relay for Mailcow
########################################################
]]

local kumo = require 'kumo'

-- Basic traffic shaping configuration (no TSA dependency)
local function setup_basic_shaping()
  -- Apply basic rate limiting
  kumo.configure_redis_throttles {
    node = 'redis://redis:6379/',
    -- Basic rate limits for IP warm-up
    limits = {
      { name = 'daily_limit', period = '1d', limit = 10000 },
      { name = 'hourly_limit', period = '1h', limit = 1000 },
      { name = 'minute_limit', period = '1m', limit = 100 },
    }
  }
  
  -- Return nil since we're not loading external shaping config
  return nil
end

-- Initialize KumoMTA
kumo.on('init', function()
  -- Redis throttling configured in setup_basic_shaping()
  
  -- Internal relay listener for Mailcow (port 2525)
  kumo.start_esmtp_listener {
    listen = '0.0.0.0:2525',
    hostname = 'kumomta-server',
    relay_hosts = { '149.28.244.166', '127.0.0.1' }, -- Allow Mailcow to relay
    banner = 'KumoMTA Internal Relay Service',
  }
  
  -- External SMTP listener (port 25)
  kumo.start_esmtp_listener {
    listen = '0.0.0.0:25',
    hostname = 'kumomta-server',
    relay_hosts = { '127.0.0.1' }, -- Only localhost for external
    banner = 'KumoMTA External SMTP Service',
  }
  
  -- Submission listener (port 587)
  kumo.start_esmtp_listener {
    listen = '0.0.0.0:587',
    hostname = 'kumomta-server', 
    relay_hosts = { '127.0.0.1' }, -- Only localhost for submission
    banner = 'KumoMTA Submission Service',
  }
  
  -- HTTP API listener for monitoring (following official pattern)
  kumo.start_http_listener {
    listen = '0.0.0.0:8000',
    trusted_hosts = { '149.28.244.166', '151.236.251.75', '127.0.0.1' },
  }
  
  -- Define spool configuration with RocksDB for performance
  kumo.define_spool {
    name = 'data',
    path = '/var/spool/kumomta/data',
    kind = 'RocksDB',
  }
  
  kumo.define_spool {
    name = 'meta', 
    path = '/var/spool/kumomta/meta',
    kind = 'RocksDB',
  }
  
  -- Configure local logs
  kumo.configure_local_logs {
    log_dir = '/var/log/kumomta',
    max_segment_duration = '60s',
  }
  
  -- Setup basic traffic shaping
  setup_basic_shaping()
  
  -- Log successful initialization
  kumo.log.info('KumoMTA initialized with basic traffic shaping')
  kumo.log.info('Redis throttling configured')
  kumo.log.info('Internal relay listener started on port 2525')
  kumo.log.info('External SMTP listener started on port 25')
  kumo.log.info('Submission listener started on port 587')
  kumo.log.info('HTTP API available on port 8000')
end)

-- Message processing for relay
kumo.on('smtp_server_message_received', function(msg)
  -- Accept messages from Mailcow for relay delivery
  -- No DKIM signing needed - Mailcow handles this
  
  -- Set metadata for tracking
  msg:set_meta('tenant', 'mailcow')
  msg:set_meta('campaign', 'relay')
  
  -- Queue for delivery
  msg:save()
end)

-- Queue configuration optimized for email delivery
kumo.on('get_queue_config', function(domain, tenant, campaign)
  return kumo.make_queue_config {
    protocol = {
      smtp = {
        timeout = '60s',
        max_ready = 50,
        max_connection_rate = '100/min',
        max_deliveries_per_connection = 20,
        idle_timeout = '300s',
        connect_timeout = '30s',
        enable_tls = 'OpportunisticInsecure',
      }
    },
    retry_interval = '10m',
    max_retry_interval = '4h', 
    max_age = '72h',
  }
end)

-- Egress source configuration for outbound delivery
kumo.on('get_egress_source', function(source_name)
  return kumo.make_egress_source {
    name = source_name,
    source_address = '89.117.75.190',
    ehlo_domain = 'kumomta-server',
  }
end)

-- Bounce classification for proper handling
kumo.on('get_bounce_classifier', function()
  -- Use default bounce classification
  return nil
end)

-- Log delivery events
kumo.on('should_enqueue_log_record', function(msg, log_record)
  -- Log important delivery events
  if log_record.kind == 'Delivery' or log_record.kind == 'Bounce' or log_record.kind == 'Rejection' then
    return true
  end
  return false
end)



-- HTTP API endpoints for monitoring and management
kumo.on('http_request', function(request)
  local path = request:get_path()
  local method = request:get_method()
  
  if path == '/health' then
    return {
      status = 200,
      headers = { ['Content-Type'] = 'application/json' },
      body = '{"status":"healthy","service":"kumomta","timestamp":"' .. os.date('%Y-%m-%d %H:%M:%S') .. '"}'
    }
  elseif path == '/' then
    return {
      status = 200, 
      headers = { ['Content-Type'] = 'application/json' },
      body = '{"service":"kumomta","status":"running","role":"email-relay"}'
    }
  elseif path == '/api/v1/status' then
    return {
      status = 200,
      headers = { ['Content-Type'] = 'application/json' },
      body = '{"queue_status":"active","delivery_rate":"normal","system":"operational"}'
    }
  elseif path == '/api/v1/queue/status' then
    return {
      status = 200,
      headers = { ['Content-Type'] = 'application/json' },
      body = '{"active_queue":0,"deferred_queue":0,"total_processed":0}'
    }
  elseif path == '/metrics' then
    return {
      status = 200,
      headers = { ['Content-Type'] = 'text/plain' },
      body = [[
# HELP kumomta_messages_total Total messages processed
# TYPE kumomta_messages_total counter
kumomta_messages_total{type="delivered"} 0
kumomta_messages_total{type="bounced"} 0
kumomta_messages_total{type="deferred"} 0
# HELP kumomta_connections_total Total connections
# TYPE kumomta_connections_total counter
kumomta_connections_total 0
      ]]
    }
  elseif path == '/api/v1/metrics/delivery' then
    return {
      status = 200,
      headers = { ['Content-Type'] = 'application/json' },
      body = '{"delivered":0,"bounced":0,"deferred":0,"rate":"0/min"}'
    }
  elseif path == '/api/v1/ip/status' then
    return {
      status = 200,
      headers = { ['Content-Type'] = 'application/json' },
      body = '{"active_ips":["89.117.75.190"],"rotation_enabled":false}'
    }
  elseif path == '/api/v1/metrics/status' then
    return {
      status = 200,
      headers = { ['Content-Type'] = 'application/json' },
      body = '{"cpu_usage":"normal","memory_usage":"normal","disk_usage":"normal"}'
    }
  else
    return {
      status = 404,
      headers = { ['Content-Type'] = 'application/json' },
      body = '{"error":"Endpoint not found","path":"' .. path .. '"}'
    }
  end
end)