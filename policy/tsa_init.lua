--[[
Traffic Shaping Automation (TSA) Daemon Configuration
Handles automatic traffic shaping adjustments based on delivery feedback
]]

kumo.on('tsa_init', function()
  -- Configure TSA daemon for cold email optimization
  kumo.configure_bounce_classifier {
    files = {
      '/opt/kumomta/share/bounce_classifier/iana.toml',
    },
  }
  
  -- Enable automatic shaping adjustments
  kumo.configure_shaping_automation {
    -- Reduce sending rate on bounces/deferrals
    reduce_on_bounce = true,
    reduce_on_deferral = true,
    
    -- Recovery settings
    recovery_time = '1h',
    max_reduction_factor = 0.1, -- Reduce to 10% of original rate
    
    -- Monitoring intervals
    publish_interval = '30s',
    subscribe_interval = '30s',
  }
end)