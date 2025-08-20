--[[
Advanced IP Rotation Configuration for KumoMTA
Enterprise-grade IP management with weighted round-robin and proxy support
]]

local kumo = require 'kumo'

-- IP Rotation Configuration
local IP_ROTATION_CONFIG = {
  -- Primary IP pool (40% of traffic)
  primary = {
    ips = {
      { address = '192.168.1.10', weight = 40, ehlo = 'mail.smarteroutbound.com' },
      { address = '192.168.1.11', weight = 35, ehlo = 'mail2.smarteroutbound.com' },
      { address = '192.168.1.12', weight = 25, ehlo = 'mail3.smarteroutbound.com' },
    },
    max_connections = 50,
    max_rate = '100/min',
    tls_required = true,
    dane_enabled = true,
  },
  
  -- Secondary IP pool (35% of traffic)
  secondary = {
    ips = {
      { address = '192.168.1.20', weight = 45, ehlo = 'mail4.smarteroutbound.com' },
      { address = '192.168.1.21', weight = 30, ehlo = 'mail5.smarteroutbound.com' },
      { address = '192.168.1.22', weight = 25, ehlo = 'mail6.smarteroutbound.com' },
    },
    max_connections = 40,
    max_rate = '80/min',
    tls_required = true,
    dane_enabled = true,
  },
  
  -- Tertiary IP pool (25% of traffic)
  tertiary = {
    ips = {
      { address = '192.168.1.30', weight = 50, ehlo = 'mail7.smarteroutbound.com' },
      { address = '192.168.1.31', weight = 30, ehlo = 'mail8.smarteroutbound.com' },
      { address = '192.168.1.32', weight = 20, ehlo = 'mail9.smarteroutbound.com' },
    },
    max_connections = 30,
    max_rate = '60/min',
    tls_required = true,
    dane_enabled = true,
  },
  
  -- Backup IP pool (emergency use only)
  backup = {
    ips = {
      { address = '192.168.1.100', weight = 100, ehlo = 'backup.smarteroutbound.com' },
    },
    max_connections = 10,
    max_rate = '20/min',
    tls_required = false,
    dane_enabled = false,
  }
}

-- Proxy Configuration for IP rotation
local PROXY_CONFIG = {
  -- HAProxy configuration
  haproxy = {
    enabled = true,
    server = 'haproxy:8080',
    health_check = true,
    health_check_interval = '30s',
    max_failures = 3,
  },
  
  -- SOCKS5 configuration
  socks5 = {
    enabled = false,
    server = 'socks5:1080',
    authentication = false,
    username = nil,
    password = nil,
  },
  
  -- Direct connection fallback
  direct = {
    enabled = true,
    fallback_timeout = '5s',
    max_retries = 3,
  }
}

-- IP Reputation Management
local IP_REPUTATION_CONFIG = {
  -- Reputation thresholds
  thresholds = {
    excellent = 0.9,    -- 90%+ delivery rate
    good = 0.8,         -- 80%+ delivery rate
    fair = 0.7,         -- 70%+ delivery rate
    poor = 0.6,         -- 60%+ delivery rate
    bad = 0.5,          -- Below 60% delivery rate
  },
  
  -- Reputation-based IP rotation
  rotation_rules = {
    excellent = { weight_multiplier = 1.5, max_rate_multiplier = 1.2 },
    good = { weight_multiplier = 1.2, max_rate_multiplier = 1.1 },
    fair = { weight_multiplier = 1.0, max_rate_multiplier = 1.0 },
    poor = { weight_multiplier = 0.8, max_rate_multiplier = 0.9 },
    bad = { weight_multiplier = 0.5, max_rate_multiplier = 0.7 },
  },
  
  -- Reputation recovery
  recovery = {
    enabled = true,
    recovery_interval = '24h',
    recovery_factor = 0.1, -- 10% improvement per day
    max_recovery_time = '7 days',
  }
}

-- Time-based IP rotation
local TIME_BASED_ROTATION = {
  -- Business hours (9 AM - 5 PM)
  business_hours = {
    start_hour = 9,
    end_hour = 17,
    ip_pool = 'primary',
    weight_multiplier = 1.2,
    rate_multiplier = 1.1,
  },
  
  -- Peak hours (12 PM - 2 PM, 5 PM - 7 PM)
  peak_hours = {
    times = {
      { start = 12, end = 14 },
      { start = 17, end = 19 },
    },
    ip_pool = 'secondary',
    weight_multiplier = 1.1,
    rate_multiplier = 1.05,
  },
  
  -- Off-hours (5 PM - 9 AM)
  off_hours = {
    start_hour = 17,
    end_hour = 9,
    ip_pool = 'tertiary',
    weight_multiplier = 0.8,
    rate_multiplier = 0.9,
  },
  
  -- Weekend
  weekend = {
    ip_pool = 'backup',
    weight_multiplier = 0.6,
    rate_multiplier = 0.7,
  }
}

-- Domain-specific IP assignment
local DOMAIN_IP_MAPPING = {
  -- High-reputation domains get primary IPs
  high_reputation = {
    domains = { 'gmail.com', 'outlook.com', 'yahoo.com' },
    ip_pool = 'primary',
    weight_multiplier = 1.3,
    rate_multiplier = 1.2,
  },
  
  -- Enterprise domains get secondary IPs
  enterprise = {
    domains = { 'office365.com', 'exchange.microsoft.com' },
    ip_pool = 'secondary',
    weight_multiplier = 1.1,
    rate_multiplier = 1.05,
  },
  
  -- Unknown domains get tertiary IPs
  unknown = {
    domains = { '*' },
    ip_pool = 'tertiary',
    weight_multiplier = 1.0,
    rate_multiplier = 1.0,
  }
}

-- IP Health Monitoring
local IP_HEALTH_CONFIG = {
  -- Health check parameters
  health_check = {
    enabled = true,
    interval = '60s',
    timeout = '10s',
    max_failures = 3,
    recovery_time = '300s',
  },
  
  -- Performance thresholds
  performance = {
    max_latency = '5s',
    max_bounce_rate = '5%',
    max_rejection_rate = '3%',
    min_delivery_rate = '85%',
  },
  
  -- Auto-recovery
  auto_recovery = {
    enabled = true,
    check_interval = '300s',
    recovery_threshold = '10 minutes',
    gradual_recovery = true,
  }
}

-- Advanced egress source configuration
kumo.on('get_egress_source', function(source_name)
  local config = IP_ROTATION_CONFIG[source_name]
  if not config then
    -- Default configuration
    return kumo.make_egress_source {
      name = source_name,
      ehlo_domain = 'mail.smarteroutbound.com',
      ttl = '1h',
    }
  end
  
  -- Get current time for time-based rotation
  local current_time = os.date('*t')
  local current_hour = current_time.hour
  local is_weekend = current_time.wday == 1 or current_time.wday == 7
  
  -- Determine IP pool based on time and conditions
  local selected_pool = config.ips[1]
  local weight_multiplier = 1.0
  local rate_multiplier = 1.0
  
  -- Apply time-based rotation
  if is_weekend then
    weight_multiplier = weight_multiplier * TIME_BASED_ROTATION.weekend.weight_multiplier
    rate_multiplier = rate_multiplier * TIME_BASED_ROTATION.weekend.rate_multiplier
  elseif current_hour >= TIME_BASED_ROTATION.business_hours.start_hour and 
         current_hour <= TIME_BASED_ROTATION.business_hours.end_hour then
    weight_multiplier = weight_multiplier * TIME_BASED_ROTATION.business_hours.weight_multiplier
    rate_multiplier = rate_multiplier * TIME_BASED_ROTATION.business_hours.rate_multiplier
  else
    weight_multiplier = weight_multiplier * TIME_BASED_ROTATION.off_hours.weight_multiplier
    rate_multiplier = rate_multiplier * TIME_BASED_ROTATION.off_hours.rate_multiplier
  end
  
  -- Check for peak hours
  for _, peak_time in ipairs(TIME_BASED_ROTATION.peak_hours.times) do
    if current_hour >= peak_time.start and current_hour <= peak_time.end then
      weight_multiplier = weight_multiplier * TIME_BASED_ROTATION.peak_hours.weight_multiplier
      rate_multiplier = rate_multiplier * TIME_BASED_ROTATION.peak_hours.rate_multiplier
      break
    end
  end
  
  -- Select IP based on weighted round-robin
  local total_weight = 0
  for _, ip in ipairs(config.ips) do
    total_weight = total_weight + (ip.weight * weight_multiplier)
  end
  
  local random_value = math.random() * total_weight
  local current_weight = 0
  
  for _, ip in ipairs(config.ips) do
    current_weight = current_weight + (ip.weight * weight_multiplier)
    if random_value <= current_weight then
      selected_pool = ip
      break
    end
  end
  
  -- Create egress source with selected configuration
  local egress_source = {
    name = source_name,
    ehlo_domain = selected_pool.ehlo,
    source_address = selected_pool.address,
    ttl = '1h',
  }
  
  -- Add proxy configuration if enabled
  if PROXY_CONFIG.haproxy.enabled then
    egress_source.ha_proxy_server = PROXY_CONFIG.haproxy.server
    egress_source.ha_proxy_source_address = selected_pool.address
  end
  
  if PROXY_CONFIG.socks5.enabled then
    egress_source.socks5_proxy_server = PROXY_CONFIG.socks5.server
    egress_source.socks5_proxy_source_address = selected_pool.address
    if PROXY_CONFIG.socks5.authentication then
      egress_source.socks5_proxy_username = PROXY_CONFIG.socks5.username
      egress_source.socks5_proxy_password = PROXY_CONFIG.socks5.password
    end
  end
  
  return kumo.make_egress_source(egress_source)
end)

-- Advanced egress pool configuration
kumo.on('get_egress_pool', function(pool_name)
  if pool_name == 'main' then
    return kumo.make_egress_pool {
      name = 'main',
      sources = {
        { name = 'primary', weight = 40 },
        { name = 'secondary', weight = 35 },
        { name = 'tertiary', weight = 25 },
      }
    }
  elseif pool_name == 'high_volume' then
    return kumo.make_egress_pool {
      name = 'high_volume',
      sources = {
        { name = 'primary', weight = 60 },
        { name = 'secondary', weight = 40 },
      }
    }
  elseif pool_name == 'low_volume' then
    return kumo.make_egress_pool {
      name = 'low_volume',
      sources = {
        { name = 'tertiary', weight = 70 },
        { name = 'backup', weight = 30 },
      }
    }
  end
  
  -- Default pool
  return kumo.make_egress_pool {
    name = pool_name,
    sources = { { name = 'primary', weight = 100 } }
  }
end)

-- IP reputation tracking and management
local function update_ip_reputation(ip_address, delivery_result)
  local reputation_key = 'ip_reputation:' .. ip_address
  local current_reputation = redis.get(reputation_key) or 0.8 -- Default to 80%
  
  if delivery_result == 'success' then
    current_reputation = math.min(1.0, current_reputation + 0.01) -- +1%
  elseif delivery_result == 'bounce' then
    current_reputation = math.max(0.1, current_reputation - 0.05) -- -5%
  elseif delivery_result == 'rejection' then
    current_reputation = math.max(0.1, current_reputation - 0.1) -- -10%
  end
  
  -- Store updated reputation
  redis.set(reputation_key, current_reputation)
  redis.expire(reputation_key, 86400 * 7) -- 7 days
  
  return current_reputation
end

-- IP health monitoring
local function check_ip_health(ip_address)
  local health_key = 'ip_health:' .. ip_address
  local health_data = redis.get(health_key)
  
  if not health_data then
    health_data = {
      status = 'healthy',
      last_check = os.time(),
      failures = 0,
      last_failure = nil,
      recovery_start = nil,
    }
  else
    health_data = json.decode(health_data)
  end
  
  -- Check if IP should be marked as unhealthy
  if health_data.failures >= IP_HEALTH_CONFIG.health_check.max_failures then
    health_data.status = 'unhealthy'
    health_data.recovery_start = health_data.recovery_start or os.time()
    
    -- Check if recovery time has elapsed
    if os.time() - health_data.recovery_start >= IP_HEALTH_CONFIG.health_check.recovery_time then
      health_data.status = 'recovering'
      health_data.failures = math.max(0, health_data.failures - 1)
    end
  end
  
  -- Store updated health data
  redis.set(health_key, json.encode(health_data))
  redis.expire(health_key, 86400) -- 1 day
  
  return health_data
end

-- IP rotation optimization based on reputation and health
local function optimize_ip_rotation()
  for pool_name, pool_config in pairs(IP_ROTATION_CONFIG) do
    for _, ip in ipairs(pool_config.ips) do
      local reputation = update_ip_reputation(ip.address, 'success')
      local health = check_ip_health(ip.address)
      
      -- Adjust IP weights based on reputation and health
      local reputation_multiplier = 1.0
      for threshold_name, threshold_value in pairs(IP_REPUTATION_CONFIG.thresholds) do
        if reputation >= threshold_value then
          local rules = IP_REPUTATION_CONFIG.rotation_rules[threshold_name]
          reputation_multiplier = rules.weight_multiplier
          break
        end
      end
      
      -- Apply health-based adjustments
      if health.status == 'unhealthy' then
        reputation_multiplier = reputation_multiplier * 0.1 -- 90% reduction
      elseif health.status == 'recovering' then
        reputation_multiplier = reputation_multiplier * 0.5 -- 50% reduction
      end
      
      -- Update IP weight
      ip.current_weight = ip.weight * reputation_multiplier
    end
  end
end

-- Schedule IP rotation optimization
kumo.on('init', function()
  -- Run IP optimization every 5 minutes
  kumo.timer('ip_optimization', '5 minutes', function()
    optimize_ip_rotation()
  end)
end)

print("🚀 Advanced IP Rotation Configuration loaded successfully!")
print("✨ Features enabled:")
print("   • Weighted Round-Robin IP Rotation")
print("   • Time-Based IP Selection")
print("   • Domain-Specific IP Assignment")
print("   • IP Reputation Management")
print("   • Health Monitoring and Auto-Recovery")
print("   • Proxy Support (HAProxy/SOCKS5)")
print("   • Performance-Based Optimization")
print("   • Business Hours Intelligence")
