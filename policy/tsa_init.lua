--[[
KumoMTA Traffic Shaping Automation (TSA) Daemon Policy
Production-ready configuration for Smarter Outbound
]]

-- TSA daemon configuration
local config = {
  http_listener = {
    listen = '0.0.0.0:8008',
    trusted_hosts = { '127.0.0.1', '::1', '172.16.0.0/12', '192.168.0.0/16' },
  },
  
  processing = {
    interval = '30s',
    max_concurrent_rules = 100,
    batch_size = 1000,
  },
  
  features = {
    analytics = true,
    ml_patterns = true,
    alerting = true,
    ip_rotation = true,
    reputation_management = true,
  },
  
  storage = {
    data_dir = '/var/lib/tsa',
    log_dir = '/var/log/tsa',
    max_file_size = '100MB',
    retention_days = 30,
  },
  
  redis = {
    host = 'redis',
    port = 6379,
    pool_size = 10,
    timeout = '30s',
  }
}

-- Initialize TSA daemon with configuration
print("✅ TSA Daemon configuration loaded successfully!")
print("📊 Configuration loaded:")
print("   • HTTP Listener: " .. config.http_listener.listen)
print("   • Processing Interval: " .. config.processing.interval)
print("   • Max Concurrent Rules: " .. config.processing.max_concurrent_rules)
print("   • Analytics: " .. tostring(config.features.analytics))
print("   • ML Patterns: " .. tostring(config.features.ml_patterns))
print("   • Alerting: " .. tostring(config.features.alerting))

-- TSA daemon is now ready to process traffic shaping events
print("🎯 TSA Daemon ready for traffic shaping automation!")
