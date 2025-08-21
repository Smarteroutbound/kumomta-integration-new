-- Minimal KumoMTA Policy Configuration
-- Simplified for production deployment

local kumo = require 'kumo'

-- Basic logging configuration
kumo.on('init', function()
  kumo.set_diagnostic_log_filter('kumod=info')
  print('🚀 KumoMTA initialized with minimal policy')
end)

-- Basic SMTP listener configuration
kumo.on('smtp_server_message_received', function(msg)
  -- Accept all messages for now
  print('📧 Message received from: ' .. tostring(msg:from()))
  return 'accept'
end)

-- Basic delivery configuration
kumo.on('get_queue_config', function(domain, tenant, campaign)
  return kumo.make_queue_config {
    protocol = {
      smtp = {
        -- Basic SMTP configuration
        timeout = '60s',
        max_ready = 10,
        max_connection_rate = '100/min',
      }
    }
  }
end)

-- Basic egress configuration
kumo.on('get_egress_source', function(source_name)
  return kumo.make_egress_source {
    name = source_name,
    source_address = '0.0.0.0',
  }
end)

-- Health check endpoint
kumo.on('http_message_generated', function(msg)
  if msg:get_meta('queue') == 'health_check' then
    return 'delivered'
  end
end)

print('✅ Minimal KumoMTA policy loaded successfully')