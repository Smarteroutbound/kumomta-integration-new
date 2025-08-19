-- policy/redis_config.lua
-- Redis configuration following official KumoMTA patterns

local M = {}

-- This function sets up Redis throttles using the official KumoMTA pattern
function M.setup_redis()
  -- Configure Redis throttles for shared rate limiting
  kumo.configure_redis_throttles { 
      node = 'redis://redis:6379/' 
  }
  
  kumo.log.info('Redis throttles configured successfully')
end

-- This function is a helper to get a redis connection from other files
function M.get_connection()
  return kumo.redis_pool_by_name('redis-main'):get_connection()
end

return M