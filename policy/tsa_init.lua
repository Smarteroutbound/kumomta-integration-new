-- TSA (Traffic Shaping Automation) Configuration
-- Based on official KumoMTA examples

local kumo = require 'kumo'
local shaping = require 'policy-extras.shaping'

kumo.on('init', function()
  -- Configure Redis connection for shared state
  kumo.configure_redis_throttles {
    node = 'redis://redis:6379/',
  }
  
  -- Setup shaping with Redis backend
  shaping:setup_with_automation {
    extra_files = { '/opt/kumomta/etc/policy/shaping.toml' },
    publish = { 'redis://redis:6379/' },
    subscribe = { 'redis://redis:6379/' },
  }
end)